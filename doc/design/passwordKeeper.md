# Why a password keeper.
Password keeper remember the password for the certain service, mostly collectors' sources, and save user from retype it.

Source like twitter requires user authentication. We don't use OAuth to do the crawling work, because many services don't have OAuth and those have OAuth usually shadows so many restrictions upon it. We may support OAuth crawler but it's not within this paper.

Password are used once the authentication is done, and we only save the authentication token like cookies. This approach require user to give password every time a authentication expires. A password keeper comes to rescue.

# Thouth on problem we faced.
1. Security - how to put password safely.
2. Invalidation - when should we consider the password is outdated and reask.

## Security
I have some options.

1. save password as plain text persistently.
2. save password as plain text but only in memory not in db(restart and forgot)
3. save password encrypted persistently which can be decrypt from a *known password*.
4. save password encrypted in memory which can be decrypt from a *known password*.
5. save password encrypted persistantly which can only decrypt by a *root password* from user which requires user to enter in the session. I buffer the root password in memory and encrypted password persistantly into db.

For user convinience the 1. is the best.
For security the 5. is the best.

Facing a trained hacker, the 1,2,3,4 have the same security problem.
2,4 are less risky because we don't save it in db, only in memory.
Difference between 1,2 vs 3,4 are just cheating ourself. Since everybody known password encrypted is the same as plain text. But it increase the cost to hack it, still worth while. Especially the case in memory.

I may choose one in 3,4,5. Since from 1,2 to 3,4 only add a simple hard coded work.

3 -> persistent user only type once, but into db anyone can hack it.
4 -> only in memory less risky but less convinient,need retype after restart at auth fail.
5 -> most secure solution we only buffer root password in memory(session).

Since 4 is even less convinient than 5.(we only type root password for once after restart while 5 retype everypassword).

So I only choose between 3,5.

Since security should never be compromised.I may only use 3 as a temprory solution.
But I'm tired of a temprory solution. I will finally need more than tripple time to fix it.

I tend to directly go into solution 5 at the time of writing @@date.now(2015年 04月 22日 星期三 10:52:09 CST).

## Invalidation
The saved password may be changed, then we should recognize it and invalidate it.

I can remember the password the first time it got authentication done.
I may invalidate it when authentication failed and reauth using the saved password still failed.

But the invalidation is kind of tricky. I cannot rely on `Errors.AuthorizationFailed` because auth failure during the authorization are likly turned into a `Errors.AuthorizationFailed` anyway. I can may not tell a network error from a password error. I may need to redesign the authorization process and refactor the collector to overcome this problem.


# finally the overall design

## overview

Strategy:
We force user to use a Master password. But forget about it and reset it is acceptable, just all remembered password are invalidated.

## Frontend
1. a master password setter.
   [help message]  tell user why a master password is required. And...
       * you can leave it empty if you don't care.
       * you can safely forgot about it, but just retype some of the source password again.
       * if left empty we will not save the source password without master password.
   [password INPUT(no confirm)] input box to set root password.
   [set password BUTTON(no cancel)] a button to confirm set the password.

2. a root password asker prompted when backend require a root password to decrypt a source password.
   [password] ...
   [ok BUTTON] ...
   [no BUTTON] will need to retype the source password.
## Backend 
1. Add AuthorizationRecovering state
2. Add AuthenticationInvalidate Error to indicate the incorrect password or username.

## work flow
MasterPasswordManager = MPM
MPM has the following 3 state.
- [noMasterPassword] master password hasn't been set even once. This stae is made by checking the `masterPasswordHash` is null
- [noLivingMasterPassword] no master password plaintext available in the session, but there is a `masterPasswordHash`.
- [hasLivingMasterPassword] we have the password plaintext in mem and hash matchs the master password hash.

0. MPM load `masterPasswordHash` from db.
1. [user] subscribe a source require auth.
2. Check if we have the username/password for the source
   - we have it and ask MPM to decrypt it. goto 3
   - [requireAuth] we don't have it. just emit `requireAuth`
   - [localAuthed] goto 4
3. MPM recieve decrypt request, do following based on state
   - when in [noMasterPassword] ask user to set one and save hash and set password, but still return DecryptError not set.
     This situation may not happen, because when no master password init, there is likely no source password cipher, so the source may not even ask for a master password.
   - when in [noLivingMasterPassword]
     Asker frontend client to give a password, and huang until client return.
4. Continue the authorization
   
   2. We check and find there is no `masterPasswordHash` and we prompt for

## work to do
- [ ] update the server/client structure and give a serverState API. see ./serverClientCommunication.md
- [ ] write MPM and togather refactor the collectors.
- [ ] write test for collectors.

