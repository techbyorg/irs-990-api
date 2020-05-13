## README
This was never really intended to be used by others, so the code is probably a little confusing :P But hopefully it's helpful.

### Getting Started
`npm install`

Have ScyllaDB/Cassandra, Elasticsearch and Redis running (Docker commands below work)
- `docker run -i --rm --name scylla -p 9042:9042 -v /var/lib/scylla:/var/lib/scylla -t scylladb/scylla:3.0.0`
- `docker run -p 9200:9200 -p 9300:9300 -v /data:/data -e "discovery.type=single-node" -e "cluster.routing.allocation.disk.threshold_enabled=false" docker.elastic.co/elasticsearch/elasticsearch-oss:7.5.2`
- `docker run -i --rm --name redis -p 6379:6379 -v /data:/data -t redis:3.2.0`

`npm run dev`

### Pulling in data
Everything is just a route. This was an easy way for me to deploy to a bunch of high-cpu kubernetes pods to process as quickly as possible. The routes typically add a bunch of jobs, then any node can handle the jobs.

http://localhost:3000/loadAllForYear?year=YYYY (eg 2017)
  - if you leave year blank, it'll pull in a small sample of eins from /data/sample_index.json

http://localhost:3000/processUnprocessedOrgs
  - this will take a while
  - if I remember right, I spun had at least 4 pods w/ 4 CPU each processing jobs for this

http://localhost:3000/processUnprocessedFunds (990PF)
  - this will also take a while

http://localhost:3000/setNtee
  - this will also take a while
  - sets the ntee for every org

http://localhost:3000/lastYearContributions
  - this set a field in ES for how much the org/fund contributed to other orgs the prior year
  - this was used for following route (parseGrantMakingWebsites)

http://localhost:3000/parseGrantMakingWebsites
  - this went through every grant-giving org that gave a decent amount of grants, and pulled in all keywords from their site, to allow searching by keywords (I was trying to find data-driven grant-giving websites)
  - you can tweak the fns for your own purpose

### Examples
This doesn't actually take advantage of Elasticsearch yet :P I'd have to write some more graphql resolvers for search

Types: IrsOrg, IrsFund, IrsOrg990, IrsFund990, IrsPerson

Get schema for a type (IrsOrg for example) so you know all fields you can specify (or just look at the type.graphql files)
```
{
	"query": "{ __type(name: \"IrsOrg\") { name fields { name type { name kind ofType { name kind } } } } }"
}
```

Get an org
```
POST http://localhost:3000/graphql {
	"query": "query ($ein: String!) {irsOrg(ein: $ein) {ein, name, assets} }",
	"variables": { "ein": "586347523" }
}
```

Get a fund (private foundation)
```
POST http://localhost:3000/graphql {
	"query": "query ($ein: String!) {irsFund(ein: $ein) {ein, name} }",
	"variables": { "ein": "586347523" }
}
```

Get 990s for an org
```
POST http://localhost:3000/graphql {
	"query": "query ($ein: String!) {irsOrg990s(ein: $ein) {ein, year} }",
	"variables": { "ein": "586347523" }
}
```


Get 990s for a fund
```
POST http://localhost:3000/graphql {
	"query": "query ($ein: String!) {irsFund990s(ein: $ein) {ein, year} }",
	"variables": { "ein": "586347523" }
}
```

Get all people at an org
```
POST http://localhost:3000/graphql {
	"query": "query ($ein: String!) {irsPersons(ein: $ein) {ein, name, title, compensation} }",
	"variables": { "ein": "586347523" }
}
```
