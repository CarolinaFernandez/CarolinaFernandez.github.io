---
layout: post-math
title:  "Lessons learnt from P4Runtime"
description: "Lessons learnt from implementing a P4Runtime-based Control Plane"
date:   2020-08-05 19:23:05
categories: development
tags: [p4, c++]
comments: true
---

* TOC
{:toc}

The tips here documented come from the implementation of a Control Plane following the P4Runtime specification ([v1.2.0](https://p4.org/p4runtime/spec/v1.2.0/P4Runtime-Spec.html#sec-bytestrings)). Comments and sample implementations are given for C++.

<!--more-->

### APIs and expected workflow

The P4Runtime API defines the following methods (see the [p4.v1.p4runtime proto](https://github.com/p4lang/p4runtime/blob/master/proto/p4/v1/p4runtime.proto) file). In order of expect appearance:

* *StreamChannel*: bidirectioanl stream started by the controller (used to set up arbitration, check session liveness, bidirectional data and event/notification transmission)
* *SetForwardingPipelineConfig*: transmit the P4 pipeline to the target, sending the P4Info file and the binary device config (both generated when compiling the P4 pipeline). Check an example of the <code>--config</code> parameter in the [p4runtime-shell](https://github.com/p4lang/p4runtime-shell/#using-the-shell) implementation
* *GetForwardingPipelineConfig*: retrieve the P4 pipeline from the target, as a P4Info object (which can be iterated to retrieve all available P4 Entities)
* *Write*: register any kind of P4 entity in the target
* *Read*: retrieve any kind of P4 entity from the target
transmit the P4 pipeline to the target, sending the P4Info file and the binary device config (both generated when compiling the P4 pipeline)
* *Capabilities*: retrieve arbitraty kind of metadata exposed by the server (e.g., the version of the API)

### StreamChannel

The *StreamChannel* object is used during the initial handshake and must be closed when tearing down the connection between controller and target. The object of this type is also used to read new incoming messages (target to controller) and write new outgoing messages (controller to target). The methods to read incoming/ingress and write outgoing/egress data are likely to be background process, which will be terminated once there is nothing else more to read or write, or under any other assumption tailored to the specific needs.

Note that reading on this stream is a blocking operation, so it will be always expect a message to be consumed. If this is not the case, it will be blocked until retrieving a new message. Therefore, use with caution. This method is typically found inside a loop. A mechanism to close the stream and the whole connection will be needed.

### P4Info

The *P4Info* object contains all the P4 Entities (or types of resources) available in the target. Check the [p4.config.v1.p4info proto](https://github.com/p4lang/p4runtime/blob/master/proto/p4/config/v1/p4info.proto) file for an exhaustive list.

When using any of the language-specific binding, import the files generated from these proto files so that your IDE can indicate how to access each field.

For instance, the following iterates on the available tables (and its related match and actions), as found in a given P4Info object:

{% include codeblock-header.html %}
```cpp
#define P4_CONFIG_NAMESPACE_ID p4::config::v1
#include "/path/to/grpc/p4/config/v1/p4info.pb.h"

void print_p4info(::P4_CONFIG_NAMESPACE_ID::P4Info p4info) {
  int table_size = p4info.tables_size();
  std::cout << "Number of tables: " << table_size << std::endl;
  for (::P4_CONFIG_NAMESPACE_ID::Table table : p4info.tables()) {
    std::cout << "  Table id: " << table.preamble().id() << std::endl;
    std::cout << "  Table name: " << table.preamble().name() << std::endl;
    for (::P4_CONFIG_NAMESPACE_ID::MatchField match_field : table.match_fields()) {
      std::cout << "    Match id: " << match_field.id() << std::endl;
      std::cout << "    Match name: " << match_field.name() << std::endl;
      std::cout << "    Match bitwidth: " << match_field.bitwidth() << std::endl;
      std::cout << "    Match type: " << match_field.match_type() << std::endl;
    }
    for (::P4_CONFIG_NAMESPACE_ID::ActionRef action_ref : table.action_refs()) {
      for (::P4_CONFIG_NAMESPACE_ID::Action action : p4info.actions()) {
        if (action_ref.id() == action.preamble().id()) {
          std::cout << "    Action id: " << action.preamble().id() << std::endl;
          std::cout << "    Action name: " << action.preamble().name() << std::endl;
          for (::P4_CONFIG_NAMESPACE_ID::Action_Param param : action.params()) {
            std::cout << "      Action param id: " << param.id() << std::endl;
            std::cout << "      Action param name: " << param.name() << std::endl;
            std::cout << "      Action param bitwidth: " << param.bitwidth() << std::endl;
          }
        }
      }
    }
  }
}
```

### IDs

Each resource is given an ID. When the P4Info object is obtained from the <code>GetForwardingPipelineConfig</code> method, the IDs of each type of P4 Entity can be obtained by iterating on such object. For instance, the ID of a table will be useful to retrieve its related attributes (match, parameters, entries).

When an ID is unknown or you would like to retrieve all resources, use "0" as an ID.

### Bytestring

The [bytestrings](https://p4.org/p4runtime/spec/v1.2.0/P4Runtime-Spec.html#sec-bytestrings) expected by the P4Runtime server are strings that contain the decimal value but are converted to **bytes** values (e.g., "0002") , not strings with hexadecimal values (e.g., "\0x02").

Also, the length of such strings should be the one defined by the size of the field (the bitwidth). Therefore, if the length of the binary value used to represent such value is lower than the bitwidth expected, the rest has to be filled up with zeros. For instance, for a field representing a port that is defined by the P4 program to fill up to 7 bytes, but its value occupies 1 byte, there will be (bitwidth - len(bytestring) = 7 - 1 = 6) zeros padded in the most significant bits; that is:

* length of field (bitwidth) = 7
* value = 2
* length of bytestring value = 1
* bytestring value = 2
* length of bytestring value with padding = 7 - 1 = 6
* bytestring value with padding = 0000002

These have to be **encoded** when sending from the client to the server and **decoded** when the client receives the value from the server.

#### Encoding to bytestring

Given a numeric value (note: here, 16 bits / 2 bytes) and the length it should take, this method will:

1. Retrieve each digit, from its most (left) to least (right) (e.g., {% raw %}$$b_N...b_1b_0$${% endraw %}) and convert to bit
1. Get the number of bits taken to represent this information
1. Introduce zero padding (as most-significant bits); that is, append to the left N 0's so that the length of the bitstring equals the expected bitwidth

Some examples (note that the X's are empty positions to be filled/padded with zeros):

| Value | Binary value | Bitwidth for field | Padded value |
|:----:|:------------|:----:|:------|:------------|
| 2 | 10 | 7 | XXXXX10 {% raw %}$$\rightarrow$${% endraw %} 0000010 |
| 78 | 1001110 | 8 | X1001110 {% raw %}$$\rightarrow$${% endraw %} 01001110 |
| 254 | 11111110 | 8 | 11111110 |
| 00:00:00:00:00:02 | 10 | 48 | XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXX10 {% raw %}$$\rightarrow$${% endraw %} 00000000 00000000 00000000 00000000 00000000 00000010 |

{% include codeblock-header.html %}
```cpp
std::string encode_value(uint16_t value, size_t bitwidth) {
  char lsb, msb;
  std::string res;

  // 1
  msb = value & 0xFF;
  lsb = value >> 8;
  res.push_back(msb);
  if (lsb != 0) {
    res.push_back(lsb);
  }

  // 2
  size_t nbytes = (bitwidth + 7) / 8;
  int remaining_zeros = nbytes - res.size();

  // 3
  std::string res_byte = "";
  while (remaining_zeros-- > 0) {
    msb = 0 & 0xFF;
    res_byte.push_back(msb);
    res = res_byte + res;
    res_byte = "";
  }

  return res;
}
```

#### Decoding from bytestring

Given an encoded value, this method will:

1. For each N-th position in the string, shift {% raw %}$$length(string)-N-1$${% endraw %} positions to the left
1. Run an OR (or "sum") of each iterated content

For instance, the string with value "000010" and length 6 will go through the following process:

{% raw %}$$position=i \rightarrow string[b_i] << length(string)-i-1 = string[b_i] << 6-i-1 $${% endraw %}

Where each iteration will be sumed/OR-ed:

{% raw %}$$\sum_{i=0}^{k=length-1} {string[b_i]} * 2^{k-i}\$${% endraw %}

And the final summed value can be converted to an unsigned integer.

The full set of iterations expected for this value (note that the X's are empty positions to be filled/padded with zeros):

| Position | String digit | Positions to shift to left | Value for iteration |
|:----:|:------------|:----:|:------|:------------|
| 0 | {% raw %}$$string[b_0]$${% endraw %} = 0 | 6-0-1 = 5 | 000000 |
| 1 | {% raw %}$$string[b_1]$${% endraw %} = 0 | 6-1-1 = 4 | X00000 {% raw %}$$\rightarrow$${% endraw %} 000000 |
| 2 | {% raw %}$$string[b_2]$${% endraw %} = 0 | 6-2-1 = 3 | XX0000 {% raw %}$$\rightarrow$${% endraw %} 000000 |
| 3 | {% raw %}$$string[b_3]$${% endraw %} = 0 | 6-3-1 = 2 | XXX000 {% raw %}$$\rightarrow$${% endraw %} 000000 |
| 4 | {% raw %}$$string[b_4]$${% endraw %} = 1 | 6-4-1 = 1 | XXXX10 {% raw %}$$\rightarrow$${% endraw %} 000010 |
| 5 | {% raw %}$$string[b_5]$${% endraw %} = 0 | 6-5-1 = 0 | XXXXX0 {% raw %}$$\rightarrow$${% endraw %} 000000 |

Sum of all the iterations/positions = 000010 {% raw %}$$\rightarrow$${% endraw %} 2

{% include codeblock-header.html %}
```cpp
uint16_t decode_value(const std::string value) {
  uint16_t res = 0;

  for (int i = 0; i < value.size(); i++) {
    res += uint16_t(value[i]) << value.size()-i-1;
  }

  return res;
}
```
