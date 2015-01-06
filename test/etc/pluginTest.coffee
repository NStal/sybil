Dependency = (require "../core/pluginCenter.coffee").Dependency
Dependencies = (require "../core/pluginCenter.coffee").Dependencies

describe "test plugin",()->
    it "test dependencies",(done)->
        A = {name:"A",requires:["B","C","D"]}
        B = {name:"B",requires:["D"]}
        C = {name:"C",requires:["B"]}
        D = {name:"D",requires:[]}
        ds = new Dependencies()
        ds.add A
        ds.add B
        ds.add C
        ds.add D
        console.log ds.get("A").flatten()
        console.log ds.get("B").flatten()
        console.log ds.get("C").flatten()
        console.log ds.get("D").flatten()
        done()
    it "recursive dependencies should fail",(done)->
        A = {name:"A",requires:["B","C","D"]}
        B = {name:"B",requires:["D"]}
        C = {name:"C",requires:["B"]}
        D = {name:"D",requires:["A"]}
        ds = new Dependencies()
        ds.add A
        ds.add B
        ds.add C
        ds.add D
        try
            console.log ds.get("A").flatten()
        catch e
            done()
    it "require unprovided dependencies should fail",(done)->
        A = {name:"A",requires:["B","C","D"]}
        B = {name:"B",requires:["D"]}
        C = {name:"C",requires:["B"]}
        D = {name:"D",requires:["X"]}
        ds = new Dependencies()
        ds.add A
        ds.add B
        ds.add C
        ds.add D
        try
            console.log ds.get("A").flatten()
        catch e
            console.error e
            done()