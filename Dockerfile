# https://hub.docker.com/_/ruby
ARG VERSION_RUBY=3.4-slim
FROM ruby:$VERSION_RUBY AS jekyll

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*
RUN gem update --system && gem install jekyll && gem cleanup

# used in the jekyll-server image, which is FROM this image
RUN cat <<'EOF' > /usr/local/bin/docker-entrypoint.sh && \
   chmod +x /usr/local/bin/docker-entrypoint.sh
#!/bin/bash
set -e

if [ ! -f Gemfile ]; then
 echo "NOTE: hmm, I don't see a Gemfile so I don't think there's a jekyll site here"
 echo "Either you didn't mount a volume, or you mounted it incorrectly."
 echo "Be sure you're in your jekyll site root and use something like this to launch"
 echo ""
 echo "docker run -p 4000:4000 -v \$(pwd):/site bretfisher/jekyll-serve"
 echo ""
 echo "NOTE: To create a new site, you can use the sister image bretfisher/jekyll like:"
 echo ""
 echo "docker run -v \$(pwd):/site bretfisher/jekyll new ."
 exit 1
fi

bundle install --retry 5 --jobs 20

exec "$@"
EOF

EXPOSE 4000
WORKDIR /site

ENTRYPOINT [ "jekyll" ]
CMD [ "--help" ]

# build from the image we just built with different metadata
FROM jekyll AS jekyll-serve

# on every container start, check if Gemfile exists and warn if it's missing
ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD [ "bundle", "exec", "jekyll", "serve", "--force_polling", "-H", "0.0.0.0", "-P", "4000" ]
