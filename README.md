Pusher
======

The centralized management system to push actions to distributed systems. This is designed for
Linux based systems.

The Administrator only needs to specify the sequence of operations (aka actions) to perform
for a set of distributed systems (servers, clients, or devices), they will poll the sequence
and apply all the operations automatically. The results will be reported by individual system
and assembled in the centralized management system.

Architecture
============

Pusher consists a centralized management system as the server, conceptually. And all distributed
systems (called client) have the Pusher Agent on each of them. The Pusher Agent is simply scheduled
by cron or similarly. It pulls any updates on the sequence from the server, and applies them.

The Addon System
================

Pusher supports a set of special operations for downloading and integrating management addons
into the Pusher Agent. With the help of the addons, the Administrator can easily specify the operations
that the specific addon is able to perform. Ideally, with addons, the Administrator can do almost
anything on a client.