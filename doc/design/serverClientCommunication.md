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



# Client Portal
Problems:
1. (SOLVE) reconnection.
   I can abort the message center
2. (SOLVE) invoke when connection is not ready.
   I can buffer it if no connection is valid.
3. (SOLVE) duplicate observe behavior
   I can has a `init` field for each observe action.
4. Error handling.
   1. Observation it will never throws error.
   2. when error ocurs it's network error.
   3. for broken connection we unset message center and inform the
      upper layer about it.
   4. the indivisual callback will never recieve a error. It will
      hang util the applyObserve successfully observe it.
   5. Usually user will see a loading hint until the error 
      solved(connection recovered). But in sybil, we will give a 
      offline hint, that should solve bad user experience.
