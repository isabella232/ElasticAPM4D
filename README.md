# ElasticAPM4D
It´s an Agent for Elastic-APM in Delphi

## Features
- Background configuration fetcher from APM Server
  - recording
  - capture_headers
  - capture_body
  - transaction_sample_rate
- Background sending of data to APM Server
- Distributed tracing (see demo below)
- Error stack traces (use "JCL" conditional define)
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

You can filter on your own custom tags / labels, so you can find for example all call's with a specific order number:
```
labels.tag_id : 22222
```

![Demo labels](/demo/labels.png?raw=true)