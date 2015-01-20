* `Dimension` (sybil/bt/ed2k a type of topology)
** `DefaultDomain`: the network have at least one default domain that maintains the client lookup topology and information exchanges.
* `Node`.(A node owner can call herself `Lord`)
* `Lord`.
* `EndPoint` (Node at connection level, may be before recognized)
** Bridged: 2 EndPoint are bridged when a `Channel` has formed between them
* `Connection` (physical connection)
** Acknownledged: my identity are accepted by remote end-point
** Confirmed: remote end-point's identity are checked and confirmed
** HalfValid: the connection is only acknownledged or confirmed
** None: the connection is neither acknownledged nor confirmed
** Valid: the connection is both acknownledged and confirmed
** Passive: if connection is created by remote end-point then the connection is passive.
* `Channel` (logical connection consist of one or more `Connection`)
** Void Channel: 2 EndPoint of the channel doesn't share any domain other than the default domain.(dimension intersection is empty without default dimension)
** Passive: if all connection of a channel is passive, the channel is passive
** Living: if a channel is not passive then it implies more connection may be opend at Lord's will, we call it living.
** Equal: conceptually, for both end-point of a channel considered the channel to be Living, than the connection is equal.

* `Domain`: portion of a `Dimension` at each `Node`
** A `Node` may be in serveral Dimension thus contains several `Domain`
** Every Node has at least a default domain for network maintainance.
