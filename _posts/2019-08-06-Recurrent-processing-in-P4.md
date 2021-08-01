---
layout: post
title:  "Recurrent processing in P4"
description: "Processing packets in a recurring fashion in P4: clone, resubmit, recirculate"
date:   2019-08-06 13:07:28
categories: development
tags: [networks, sdn, p4]
comments: true
---

* TOC
{:toc}

P4 is the acronym used to refer to *Programming Protocol-independent Packet Processors*. This language allows developing the logic of the data plane in a compliant device; explicitly defining the logic to process a packet in each of the stages, or pipelines, of the device.

Such is the freedom to implement the processing that it is possible for the developer to define any new format that suits the specific networking protocol to be tested: in the end, and speaking broadly; every parsing process takes a serialised information from the network and reconstructs it into an object that is parsed for processing -- and the way around, every deparsing takes back the packet with the new format into a serialised stream in the wire.

<!--more-->

One of the particularities of this language is that *actions* can be applied either in the ingress/egress *controls* or when *tables* are applied. A table can be applied only once, and by default a packet traverses a control once.

Some built-in actions allow the packet to be processed in a recurring manner (to be resubmitted or recirculated) or to have a copy to use (to be cloned). This <a title="GitHub repository" href="https://github.com/CarolinaFernandez/p4-tutorials" target="_blank">GitHub repository</a> introduces sample exercises for practice and this post introduces the functionality a bit more.

### Packet paths

PSA (or the *Portable Switch Architecture*) defines all the possible paths that the packets can traverse. These must be supported by any implementation of the PSA architecture in a device.

![psa_packet_paths]
<p class="image-legend"><em>Source: <a title="PSA architecture" href="https://p4.org/p4-spec/docs/PSA-v1.1.0.html" target="_blank">https://p4.org/p4-spec/docs/PSA-v1.1.0.html</a></em></p>

We are interested here in four of the paths mentioned in the diagram:
* **Resubmit**: resubmits a packet (sends the packet to the pipelines after crossing the ingress pipeline)
* **Recirculate**: recirculates a packet (sends the packet to the pipelines after crossing the ingress & egress pipelines)
* **CI2E**: clones a packet from ingress-to-egress
* **CE2E**: clones a packet from egress-to-egress

In P4_16, it seems a convention to define these as follows (*credit & thanks to <a href="https://github.com/ederollora" target="_blank">Eder Ollora</a> for finding & sharing this*):

{% include codeblock-header.html %}
```cpp
// Define constants for types of packets
#define PKT_INSTANCE_TYPE_NORMAL 0
#define PKT_INSTANCE_TYPE_INGRESS_CLONE 1
#define PKT_INSTANCE_TYPE_EGRESS_CLONE 2
#define PKT_INSTANCE_TYPE_COALESCED 3
#define PKT_INSTANCE_TYPE_INGRESS_RECIRC 4
#define PKT_INSTANCE_TYPE_REPLICATION 5
#define PKT_INSTANCE_TYPE_RESUBMIT 6
```

In the following subsections there will be code provided that makes use of such constants to identify specific types of packets and react based on it.

#### Resubmit

**Definition**: packet resubmission is a mechanism to repeat ingress processing on a packet once it has already traversed the ingress pipeline. That is: first the packet traverses the ingress pipeline, then it is sent again to the ingress pipeline.

**Trigger**: it occurs at the end of the ingress pipeline. Once the packet traverses the ingress pipeline and it finished being processed there, it enters again the ingress parser without being deparsed (keeping the same header and payload as the original packet). The ingress_port of the resubmitted packet is the same as the original packet. The packet_path of the resubmitted packet is changed to RESUBMIT.

**Implementation details**: the ingress parser distinguishes the resubmitted packet from the original packet with the packet_path field in ingress_parser_intrinsic_metadata_t. Note that this field is changed to "RESUBMIT" once the resubmission occurs. Depending on the target where the P4 program is executed, it may be possible to resubmit multiple times, and also to identify which packet is the one that was resubmitted for the N-th time.

The method in use for this is `resubmit`, defined as follows <a title="P4_16 packet redirect sample" href="https://github.com/p4lang/p4c/blob/master/testdata/p4_14_samples_outputs/packet_redirect.p4" target="_blank">here</a>:

{% include codeblock-header.html %}
```cpp
@name("._resubmit") action _resubmit() {
    resubmit({ standard_metadata, meta.metaA });
}
```

The method supports passing optional metadata as an argument. The metadata is generated during the traverse of the ingress pipeline and is available to the ingress parser in the next pass.

**Possible use cases**: as described in the PSA specification, "*to deploy multiple packet processing algorithms on the same packet. For example, the original packet can be parsed and resubmitted in the first pass with additional metadata to select one of the algorithms. Then, the resubmitted packet can be parsed, modified and deparsed using the selected algorithm.*"

#### Recirculate

**Definition**: packet recirculation is a mechanism to repeat ingress processing on a packet once it has already traversed the egress pipeline. That is: first the packet traverses both the ingress and egress pipelines, then it is sent back to the ingress pipeline to continue with the processing.

**Trigger**: it occurs at the end of the egress pipeline. When a packet is sent to the recirculate port, the packet finishes egress processing, including the egress deparser, and then re-enters the ingress parser.

**Implementation details**: as described in the PSA specification, "*a recirculated packet may have different headers compared to the headers of the packet before recirculation.*"

The method in use for this is `recirculate`, defined as follows <a title="P4_16 packet redirect sample" href="https://github.com/p4lang/p4c/blob/master/testdata/p4_14_samples_outputs/packet_redirect.p4" target="_blank">here</a>:

{% include codeblock-header.html %}
```cpp
@name("._recirculate") action _recirculate() {
    recirculate({ standard_metadata, meta.metaA });
}
```

The method supports passing optional metadata as an argument. The metadata is generated during the egress processing and is available to the ingress parser **after** the packet is recirculated.

**Implementation example**: a sample for recirculating in P4_16 is provided <a title="P4_16 sample for recirculating" href="https://github.com/CarolinaFernandez/p4-tutorials/blob/master/exercises/recirculate/solution/recirculate.p4" target="_blank">in this file</a>. Relevant code to provide this feature is documented below.

{% include codeblock-header.html %}
```cpp
#define PKT_INSTANCE_TYPE_INGRESS_RECIRC 4

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    ...

    action recirculate_packet() {
        // Send again the packet through both pipelines
        recirculate(meta.resubmit_meta);
    }

    apply {
        ...
        if (standard_metadata.instance_type != PKT_INSTANCE_TYPE_INGRESS_RECIRC) {
            // Process packet normally (first round)
            recirculate_packet();
        } else {
            // Process recirculated packet
            ...
        }
    }
}
```

**Possible use cases**: as described in the PSA specification, "*could be useful in implementing features such as multiple levels of tunnel encapsulation or decapsulation [since the headers can be different before and after a recirculation process, such fields can be used to convey that kind of data].*"

#### Cloning

**Definition**: packet cloning can create a copy of a packet and send it to a specified port (a well as the original packet). Multiple clones are allowed by a single "clone" operation, *assuming appropriate control plane configuration*.

**Trigger**: it can be triggered at the end of either the ingress or egress pipeline. In both cases, the cloned packet will be submitted to the egress pipeline; where it is accessible for further processing. The copy takes place at the PRE (*Packet Replication Engine*) component.

**Implementation details**: copying a packet expects a mirror session ID (or clone_session_id), which is a specific identifier used by the PRE to configure the values associated with the packets that are cloned in that session. Metadata is allowed as an argument, although not mandatory.

##### Cloning at ingress

**Trigger**: it occurs at the end of the ingress pipeline. Each cloned packet is a copy of the packet as it entered the ingress parser.

**Implementation details**: the method in use for this is `CloneType.I2E`, defined as follows <a title="P4_16 packet redirect sample" href="https://github.com/p4lang/p4c/blob/master/testdata/p4_14_samples_outputs/packet_redirect.p4" target="_blank">here</a>:

{% include codeblock-header.html %}
```cpp
@name("._clone_i2e") action _clone_i2e(bit<32> mirror_id) {
    clone3(CloneType.I2E, (bit<32>)mirror_id, { standard_metadata, meta.metaA });
}
```

This method expects a mirror (session) ID; defined by a specific number. Metadata information is optional.

**Implementation example**: a sample for cloning in P4_16 is provided <a title="P4_16 sample for cloning" href="https://github.com/CarolinaFernandez/p4-tutorials/blob/master/exercises/clone/solution/clone.p4" target="_blank">in this file</a>. Relevant code to provide this feature is documented below.

{% include codeblock-header.html %}
```cpp
#define PKT_INSTANCE_TYPE_INGRESS_CLONE 1

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    ...

    action clone_packet() {
        const bit<32> REPORT_MIRROR_SESSION_ID = 500;
        // Clone from ingress to egress pipeline
        clone(CloneType.I2E, REPORT_MIRROR_SESSION_ID);
    }

    apply {
        ...
        clone_packet();
    }
}

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    ...

    apply {
        if (standard_metadata.instance_type == PKT_INSTANCE_TYPE_INGRESS_CLONE) {
            // Process cloned packet
            ...
        } else {
            // Process original packet normally
            ...
        }
    }
}
```

##### Cloning at egress

**Trigger**: it occurs at the end of the egress pipeline. Each cloned packet is a copy of the modified packet after egress processing, as output by the egress deparser.

**Implementation details**: the method in use for this is `CloneType.E2E`, defined as follows <a title="P4_16 packet redirect sample" href="https://github.com/p4lang/p4c/blob/master/testdata/p4_14_samples_outputs/packet_redirect.p4" target="_blank">here</a>:

{% include codeblock-header.html %}
```cpp
@name("._clone_e2e") action _clone_e2e(bit<32> mirror_id) {
    clone3(CloneType.E2E, (bit<32>)mirror_id, { standard_metadata, meta.metaA });
}
```

This method expects a mirror (session) ID; defined by a specific number. Metadata information is optional.

**Implementation example**: following the example for the *ingress-to-egress* cloning, we could assume that a code resembling the snippet below should work (**note this is NOT tested**).

{% include codeblock-header.html %}
```cpp
#define PKT_INSTANCE_TYPE_EGRESS_CLONE 2

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    ...

    action clone_packet() {
        const bit<32> REPORT_MIRROR_SESSION_ID = 500;
        // Clone from egress to egress pipeline
        clone(CloneType.E2E, REPORT_MIRROR_SESSION_ID);
    }

    apply {
        if (standard_metadata.instance_type == PKT_INSTANCE_TYPE_EGRESS_CLONE) {
            // Process cloned packet
            ...
        } else {
            clone_packet();
            ...
        }
    }
}
```

**Possible use cases**: as described in the PSA specification, "*one use case for cloning is packet mirroring, i.e. send the packet to its normal destination according to other features implemented by the P4 program, and in addition, send a copy of the packet as received to another output port, e.g. to a monitoring device.*"

[psa_packet_paths]: /img/post/2019-08-06-Recurrent-processing-in-P4/psa_packet_paths.png?style=img-center "PSA packet paths"
