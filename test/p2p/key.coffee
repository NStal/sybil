rsaPukString = """-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDWOvsS5Xnv7iLk+ndIo9tkhOJF
EwNpwbpzmsux7yF6gx9VkjupBS/+CH+2UbZOZMdPY0e8N0S/UrXgmiJhDi39J27z
536rjo3eIoc/uRTLfzeYULKFBbi5YVvaVMNGQSC1iGtAUDVKhh24Nvk+duCwyr2s
ImDxodoGNOuT81kEhQIDAQAB
-----END PUBLIC KEY-----"""

rsaPkString = """-----BEGIN RSA PRIVATE KEY-----
MIICXgIBAAKBgQDWOvsS5Xnv7iLk+ndIo9tkhOJFEwNpwbpzmsux7yF6gx9Vkjup
BS/+CH+2UbZOZMdPY0e8N0S/UrXgmiJhDi39J27z536rjo3eIoc/uRTLfzeYULKF
Bbi5YVvaVMNGQSC1iGtAUDVKhh24Nvk+duCwyr2sImDxodoGNOuT81kEhQIDAQAB
AoGAEGPWza1M1PRtKwOWmLIgmOIpxYsc2bx+nVWce/KFpy/c99kGQ3ooH9FapAJA
ZmMDdKlt1ZKM6e5UB+kC9FX3YqEIGL0Z2tiGiKQL/lBKruHAgI8vk5/hJPIprw51
v7CkTsxEoG5GbJCUDGqrZi8tdWf++kaxrI2SsXI3AYAf+0ECQQDvReO1miPgUIwq
BGCrn7P6ZmgO2lt90pwhul+i2n6vnhLmQ9DZIg0Ni0FNTl4oBlaFF7LRIjCaDyHJ
O5F8phWdAkEA5TTrk7ALy/yFM86fHVYXZP0vDDpAout78ZVeGH4qMM7xb6MPVGoy
zMjxT5Y0n/Mi9D5qlCHk6TJiR+yuD0iqCQJBAIXo8WXDXGy/55HkXU3v1URAZ+BY
KHgklKjzq25zJg+XQjCIp6u9uNxpoSRoxZ1U3rsh5jvRDK5L5ba/lc7TDKkCQQDM
9aGjE025PzottZp7NTz+RZkIqh6akVDoGtVluYwo0ST82yceKUj77sQ6kurEDTs4
hYfwps536WIRRwfvCt9hAkEA4q3d5Gn6Bj1m5mkl0uhH2cpq/y5uBtfnAKfD8dov
3Q3MjldSckQz9vvvYrFkfXiKFGd2cONAYHVaQbYSgc2FOg==
-----END RSA PRIVATE KEY-----"""
Key = require "../../plugins/sybilP2pNetwork/network/key"
describe "rsa private key test",()->
    mk = null
    pk = null
    it "rsa private key",(done)->
        Key.MasterKey.fromPEM rsaPkString,(err,masterKey)->
            console.assert not err,"should successfully create master key"
            console.assert masterKey.toString() is rsaPkString,"toString should return original PEM"
            mk = masterKey
            console.assert mk.getPEM() is rsaPkString
            console.assert mk instanceof Key.MasterKey
            done()
    it "rsa public key from rsa",(done)->
        mk.getPublicKey (err,publicKey)->
            console.assert not err,"should successfully create public key from master key"
            console.assert publicKey.toString() is rsaPukString,publicKey.toString(),rsaPukString
            pk = publicKey
            console.assert pk.getPEM() is rsaPukString
            console.assert pk instanceof Key.PublicKey
            done()
    it "test signature",(done)->
        data = new Buffer("test string")
        mk.sign data,(err,signature)->
            console.assert Buffer.isBuffer signature
            pk.verify data,signature,(err,result)->
                console.assert not err,"verify shouldn't error"
                console.assert result,"verify should work"
                pk.verify new Buffer("hehe"),signature,(err,result)->
                    console.assert not err,"verify shouldn't error"
                    console.assert !result,"failed signature should return false"
                    done()