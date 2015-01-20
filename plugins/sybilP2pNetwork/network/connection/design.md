# Overview
 
Connections are designed to provider an uniform interface for the application layer. To make things easier to maintain. We have serveral abstractions.

# Provider
Provider is a server that can provider connection by listening to some port or local file or something like that. Provider is also responsible for opening new connection to other node of the network. All connection are under the management of provider. When Provider shuts down, all connection of the provider are force closed. And may or may not cause any `Channel` shutdown.

# Connection
Connection is a abstract interface for a certain data transfer protocol. Connection can't be rebuild and is destroyed once disconnected. This makes the design of Connection  much simpler. If reconnect is important, then it's left to the higher layer to handle it through the provider and address

# Address
We should be able to create a connection from a plain text called Address. Address is an URI like scheme://authority/path. Not every connection have a address, say for connection recieved from a listening tcp port, we don't know the remote port the remote node used for listening. But once connection has an address we should be able to create a new connection through that address.

