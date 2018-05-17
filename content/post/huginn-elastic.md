---
title: "Huginn Elastic"
date: 2018-04-04T08:54:35Z
draft: false
image: "img/generic/data.jpg"
weight: 10
categories: [ "blog" ]
showonlyimage: false
---

# Using Huginn with Elasticsearch

No one seems to have done this, or at least not written about it. So why not, it's actually pretty easy and quite useful if you'd like a tool to periodically look at your Elasticsearch data and take some actions. There are some existing tools for this but none of them could be described as user friendly or maintainable.

<!--more-->

## Acquiring the data

First I started with a Post Agent, this is documented as something which usually sends a POST request with an incomming event to some other service. However you can also schedule it to send a POST request with a manual payload and then output the response as a new event in Huginn.

```json
{
  "post_url": "http://elasticsearch:9200/duct-2018.04.03/_search",
  "expected_receive_period_in_days": "1",
  "content_type": "json",
  "method": "post",
  "payload": {
    "size": 1000,
    "sort": [
      {
        "@timestamp": {
          "order": "desc"
        }
      }
    ],
    "_source": [
      "metric",
      "hostname",
      "@timestamp",
      "state",
      "service"
    ],
    "query": {
      "range": {
        "@timestamp": {
          "gte": "now-5m"
        }
      }
    }
  },
  "headers": {
  },
  "emit_events": "true",
  "no_merge": "false",
  "output_mode": "clean"
}
```

My Elasticsearch receives events from a monitoring tool and this agent configuration does a simple search every 5 minutes for the last 5 minutes worth of data.

## Parsing the received JSON

Parsing the result of this agent requires a Website agent set as a receiver for the Post agent. There might be a better way to do this, after all there is a JSON parser agent but the documentation isn't great about how to do this.

```json
{
  "expected_update_period_in_days": "1",
  "type": "json",
  "mode": "on_change",
  "data_from_event": "{{body}}",
  "extract": {
    "service": {
      "path": "hits.hits[*]._source.service"
    },
    "state": {
      "path": "hits.hits[*]._source.state"
    },
    "hostname": {
      "path": "hits.hits[*]._source.hostname"
    },
    "date": {
      "path": "hits.hits[*]._source.@timestamp"
    },
    "metric": {
      "path": "hits.hits[*]._source.metric"
    }
  }
}
```

This will take the body of all our metrics returned by the search and simplify the result to just the elements we're interested in.

Now we can start to do things with our events

## Triggers

I started by creating a trigger to split the big stream of incomming events into smaller streams just for the data I'd like to work with. Each stream starts as follows with a Trigger agent

```json
{
  "expected_receive_period_in_days": "2",
  "keep_event": "true",
  "rules": [
    {
      "type": "field==value",
      "value": "memory",
      "path": "service"
    }
  ]
}
```

From there you can create further triggers with thresholds, or use the Peak detector agent for visualising it and alerting on peaks. When visualised this looked like this

{{< figure src="/post/images/huginn.png" title="Huginn Elasticsearch Scenario" >}}


