Pusher Agent
============

Pusher Agent is a very simple script "pusher-agent" which is usually scheduled by
cron on Linux platform. It sets up the enironment and simply transfers to Pusher
bootstrap which polls the actions and applies them.

Setup
=====

Put "pusher-agent" to your crontab, the command has no argument.

/etc/defaults/pusher must provide the following environment variables:
PUSHER_CLIENT_ID: the unqiue identifier for the client, server uses this to identify a client;
PUSHER_SERVER: the URI of server, e.g. https://server:port/prefix
