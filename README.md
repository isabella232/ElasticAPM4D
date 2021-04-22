# ElasticAPM4D
It´s an Agent for Elastic-APM in Delphi

## Features
- Background (on the fly) configuration fetcher from APM Server
  - recording
    - completely turn off any data capturing (but can be turned on again 
    runtime) 
  - transaction_sample_rate
    - record only a percentage of all http call's, e.g. 10%.
      Note: transaction's with an error are always stored (not discarded)
  - capture_headers
    - store http headers in transaction context or not
  - capture_body
    - store http body payload in transaction context or not
- Background metrics retrieval (cpu and memory)
- Background sending data to APM Server
- Distributed tracing (see demo below: for one call, record all descendant call's acros different applications or services, even async processing)
- Custom tags/labels (trace or filter multiple call's) 
- Error stack traces (enable "JCL" conditional define)
- Low overhead

## Demo

First start a local Kibana, Elastic and APM Server:
```cmd
start.bat
```
Or
```cmd
docker-compose up
```

Wait till it is completely started and open the [localhost](http://localhost:5601/app/apm/) Kibana APM page:
```
http://localhost:5601/app/apm/
```

Start both the DemoClient and DemoServer:
- /demo/DemoClient.dpr
- /demo/DemoServer.dpr

And press the demo "Http calls to server" button in the client:

![Demo client](/demo/client.png?raw=true)

You will see some test calls in the server:

![Demo server](/demo/server.png?raw=true)

The complete [trace](http://localhost:5601/app/apm/services/DemoClient/transactions/view?rangeFrom=now-15m&rangeTo=now&traceId=&transactionId=&transactionName=Test%20trace%20calls&transactionType=client) in visible Kibana:

![Demo trace](/demo/trace.png?raw=true)

### Custom tags or labels

You can filter on your own custom tags / labels, so you can find for example all call's with a specific order number:
```
labels.tag_id : 22222
```

![Demo labels](/demo/labels.png?raw=true)

### On the fly configuration

All APM recording can be turned off during runtime, by changing the [application settings](http://localhost:5601/app/apm/settings/agent-configuration/edit?name=DemoServer&environment=) in Kibana: 

![Demo settings](/demo/settings.png?raw=true)

Restart the Demo client and server, or wait 1 minute (background config fetcher).

### Alerting

Alerting can be configured via the Alerts menu:

![Alerting](/demo/alerting.png?raw=true)

For example, send an e-mail when more than 0 errors have been occured:

![Create alert](/demo/create-alert.png?raw=true)