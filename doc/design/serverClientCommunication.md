# Overview

1. Client query the complete server state at start.
2. Client observe server event to acknowledge the server state change.
3. Client may observe more or stop observe certain state after start.

group.name = data
sources.weibo_102837 = {
    ...
}

I may observe group or group.name, but currently no subfield change.

# 

ServerSide:

CoreState
ObserveWindow

==== Transportation Adapter ====

ClientSide:

ObservePortal
ShadowState


