# Specify the Dart SDK
FROM google/dart

# Resolve app dependencies.
WORKDIR /app

ADD pubspec.* /app/
RUN pub get
ADD . /app

# Ensure packages are still up-to-date if anything has changed
RUN pub get --offline

CMD []

# Start server.
EXPOSE 8080
ENTRYPOINT ["./start_server.sh"]
