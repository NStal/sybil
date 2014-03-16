
rssName="testRss1"
head = """
<?xml version='1.0' encoding='utf-8'?>
<feed xmlns='http://www.w3.org/2005/Atom'>
  <title>RSS: #{rssName}</title>
  <subtitle>#{rssName} itle</subtitle>
  <link rel='alternate' type='text/html' href='http://localhost/' />
  <link rel='self' type='application/atom+xml' href='http://localhost/' />
  <id>http://localhost/#{rssName}</id>
  <updated>#{new Date()}</updated>
  <rights>Copyright © 2010-2012, V2EX</rights>

"""
console.log head
for index in [0...100]
    title = "Rss #{rssName} title #{index}"
    link = "http://localhost/#{rssName}/link#{index}"
    id = "guid-#{rssName}-#{index}"
    publishDate = new Date()
    updateDate = new Date()
    authorName = "authorame#{index}"
    authorUrl = "None"
    content = "testContent#{index} #{Math.random()}"
    entry = """    <entry>
        <title>#{title}</title>
        <link rel='alternate' type='text/html' href='#{link}' />
        <id>#{id}</id>
        <published>#{publishDate}</published>
        <updated>#{updateDate}</updated>
        <author>
          <name>#{authorName}</name>
          <uri>#{authorUrl}</uri>
        </author>
        <content type='html' xml:base='http://localhost/' xml:lang='en'><![CDATA[
        #{content}
        ]]></content>
      </entry>
    """
    console.log(entry)
tail = "</feed>"
console.log tail
