# Keywords: Lord,Domain,Node,Channel,Connection,Key,Node Server.

# Design Goals.
I'd like to build a peer to peer (P2P) network that maintain serveral different topology, but shares the connection(s) and same basic protocol. Thus the single network can support different application without wasting time building new network and tool sets.


# Linking Phrase

Verb: Touch,Bridge,Link
We considered the whole system running locally on a certain single client a Lord. A Lord maintain at least one Domain. Domain are used to maintain a specific topology, it stores the direct connected Nodes' information. Node represents the remote client you are connect to when we talk about the detailed program design, it also refered to a single node of a certain topology or the whole network when we talk about these conceptions. By maintain different domains and they specific private protocols, we create different topology for different applications. We build Connections between Nodes and all Connections between 2 Node togather called a Channel. Connection is a transport layer conception while Channel are a higher level conception, 2 Node with any sort of connection are considered Touched. Every Node has a Key which is unique in the whole network and may also known as private-publick key pairs. After 2 Node get Touched they can exchange and authorize their Keys and then considered Bridged. So at abstract level, Bridge means 2 Nodes are physically connected and identified each other,and when satisfy the Bridge condition we declare that the 2 Nodes has a Channel. We use the Key to merge the connection that logically belongs to the same Channel when Bridging. After first Bridge, Node may exchange they domain info to add them to proper domains. After exchange domains, 2 Nodes are Linked. If they don't share any same domain, we call this Link a Void Link which will be drop by closing all connection when resource get tied. At abstract level, relation between Node have Touch,Bridge,Link,Void Link states. Note, when implementing this these conceptions, the conception Node are only available after Bridged. Before Bridging, connections are just connections, we don't know which Node or Channel it belongs to.

Many verbs at connecting phrase requires exchanges. Like exchange Keys, Domains. Any side of the node are considered equal, so we don't decide which side is initiative or passive. Thus the exchange process has several states, None,Ackownledged,Confirmed,Ackownledged-Confirmed. Ackownledged means local information are accepted by remote Node, Confirmed means Remote information are accepted by Lord. None means neither of them are done. By the way, Connections at Touch state will be closed when certain timeout reached or resource get tied. Connections at Bridge or Void Link state will be closed when resource get tied.

# Node Lookup

We can implement a DHT on top of the network, both after exchange keys as one kind of topology or just gather informations at Touch state.

# Private Connection
Usually connection in a channel are shared, when sending message, channel is responsible for picking up a proper connection. But we can create an connection and declare that it's an private connection, so the connection will not share by anyone else normally, unless someone know this connection can use it specified

# Content Lookup

Content lookup are left to application's dicision.


# Domain
Domain manage the exact topology of the network