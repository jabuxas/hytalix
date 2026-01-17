FROM hexpm/elixir:1.19.5-erlang-27.3-ubuntu-noble-20260113 AS builder

RUN apt-get update -y && apt-get install -y build-essential git curl && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

COPY config config
COPY lib lib

RUN mix deps.compile
RUN mix compile

COPY assets assets
COPY priv priv
RUN mix assets.deploy

RUN mix release

FROM ubuntu:noble AS runner

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates openjdk-17-jre-headless bash && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen 
ENV LANG en_US.UTF-8 
ENV LANGUAGE en_US:en 
ENV LC_ALL en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

COPY --from=builder --chown=nobody:root /app/_build/prod/rel/hytalix ./
COPY --chown=nobody:root mock_server.sh ./
RUN chmod +x mock_server.sh

USER nobody

CMD ["/app/bin/hytalix", "start"]
