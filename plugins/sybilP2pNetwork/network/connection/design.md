# Overview
 
Connections are designed to provider and uniform interface for the application layer. To make things easier to maintain. We have serveral abstractions.

# Provider
Provider is a server that can provider connection by listening to some port or local file or something like that. Provider is also responsible for opening new connection to other node of the network. All connection are undered the management of provider. When Provider shuts down, all connection of the provider are force closed

# Connection
Connection is a abstract interface for an certain data transfer protocol. Connection can be reconnect and is destroyed once disconnected. This makes the design of Connection  much simpler. If reconnect is important, then it's left to the higher layer to handle it throught the provider and address

# Address
We should be able to create an connection from a plain text called Address. Address is an URI like scheme://authority/path. Not every connection have address, say for connection from a tcp port, we don't know the remote port the remote node used for listening. But once connection has an address we should be able to create a new connection through that address.
