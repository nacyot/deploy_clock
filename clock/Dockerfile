FROM ruby:2.6

WORKDIR /app
ADD ./Gemfile ./Gemfile.lock /app/
RUN bundle install
ADD . /app
CMD ruby ./app.rb -o 0.0.0.0
