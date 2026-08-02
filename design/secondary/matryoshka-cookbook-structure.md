# Matryoshka Cookbook
## A Practical Guide to Building Concurrent Systems in Zig

**Status**

This document defines the complete cookbook structure.

The cookbook is built entirely from the Matryoshka API, Pattern Catalog, and existing examples.

Every recipe teaches exactly **one concept**.

Recipes are intentionally small.

Examples demonstrate systems.

Recipes teach techniques.

---

# Part I
# Ownership

Foundation concepts.

## Chapter 1 — Objects

001 Create a PolyNode object

002 Initialize embedded PolyNode

003 Destroy an object

004 Empty Slot initialization

005 Ownership begins

006 Ownership ends

007 Null Slot

008 Slot lifecycle

009 Stack allocated items

010 Heap allocated items

---

## Chapter 2 — Ownership Transfer

011 Transfer ownership

012 Sender loses ownership

013 Receiver gains ownership

014 Safe defer cleanup

015 Acquire-after-defer

016 Cleanup after transfer

017 Recover ownership

018 Prevent double ownership

019 Ownership assertions

020 Ownership debugging

---

# Part II
# Runtime Polymorphism

## Chapter 3 — PolyNode

021 PolyHelper

022 Runtime tags

023 Safe cast

024 mustCast

025 Runtime type checking

026 Wrapper items

027 MailboxHandle wrapper

028 PoolHandle wrapper

029 Mailbox as message

030 Pool as message

---

## Chapter 4 — Intrusive Lists

031 Linked vs unlinked items

032 reset()

033 is_linked()

034 Safe destroy

035 Intrusive ownership

036 List removal

037 Moving nodes

038 Queue semantics

039 FIFO ordering

040 Intrusive object lifetime

---

# Part III
# Mailboxes

## Chapter 5 — Basic Messaging

041 Create mailbox

042 Send one message

043 Receive one message

044 Receive multiple types

045 Message dispatch

046 Unknown messages

047 Ownership after receive

048 Empty mailbox

049 Multiple producers

050 Multiple consumers

---

## Chapter 6 — Advanced Mailboxes

051 try_receive()

052 receive_batch()

053 send_oob()

054 FIFO ordering

055 OOB ordering

056 Mailbox close

057 Recover queued messages

058 Mailbox shutdown

059 Mailbox reuse

060 Mailbox lifecycle

---

# Part IV
# Pools

## Chapter 7 — Object Reuse

061 Create pool

062 available_or_new

063 available_only

064 new_only

065 Return object

066 Reuse object

067 Pool ownership

068 Pool capacity

069 Pool statistics

070 Pool lifecycle

---

## Chapter 8 — Pool Policies

071 on_get

072 on_put

073 on_close

074 Object initialization

075 Object cleanup

076 Hook synchronization

077 Fixed-size pool

078 Dynamic pool

079 Multi-type pool

080 Pool seeding

---

# Part V
# Futures

## Chapter 9 — Waiting

081 Create Future

082 Await Future

083 Cancel Future

084 Future ownership

085 Waiting timeout

086 Recover after cancellation

087 Multiple Futures

088 Future cleanup

089 Future chaining

090 Future lifecycle

---

# Part VI
# Io.Group

## Chapter 10 — Worker Groups

091 Spawn worker

092 Spawn many workers

093 Await workers

094 Reuse Group

095 Worker context

096 Worker lifetime

097 Graceful worker exit

098 Cancel workers

099 Worker failures

100 Worker supervision

---

# Part VII
# Io.Select

## Chapter 11 — Event Sources

101 Register mailbox

102 Register pool

103 Register timer

104 Register external event

105 Register multiple sources

106 Wait once

107 One-shot registration

108 Register again

109 Event dispatch

110 Event ownership

---

## Chapter 12 — Event Loops

111 Master event loop

112 Mixed event sources

113 Mailbox priority

114 Pool backpressure

115 Timer integration

116 External callbacks

117 Cancellation

118 cancelDiscard()

119 Graceful shutdown

120 Restart Select

---

# Part VIII
# Cancellation

## Chapter 13 — Cancellation

121 Cancellation boundary

122 Cancel waiting

123 Close vs Cancel

124 Ownership after cancel

125 Recover resources

126 Cancel workers

127 Cancel Select

128 Cancel Future

129 Nested cancellation

130 Cancellation patterns

---

# Part IX
# Resource Management

## Chapter 14 — Backpressure

131 Pool waits

132 Producer throttling

133 Consumer throttling

134 Resource starvation

135 Automatic pacing

136 Buffer pools

137 Queue growth

138 Flow control

139 Memory limits

140 Resource exhaustion

---

# Part X
# Architectures

## Chapter 15 — Components

141 Component mailbox

142 Component pool

143 Component ownership

144 Component lifecycle

145 Component shutdown

146 Message protocols

147 Shared pools

148 Shared mailboxes

149 Dispatcher component

150 Supervisor component

---

## Chapter 16 — Communication

151 Producer/Consumer

152 Request/Reply

153 Fan-Out

154 Fan-In

155 Pipeline

156 Broadcast

157 Scatter/Gather

158 Command processing

159 Event processing

160 Work queues

---

## Chapter 17 — Worker Architectures

161 Worker farm

162 Shared resource pool

163 Dynamic workers

164 Static workers

165 Load balancing

166 Backpressure

167 Result collection

168 Worker supervision

169 Graceful shutdown

170 Error propagation

---

## Chapter 18 — Master Architectures

171 Master + Workers

172 Thin run()

173 Central event loop

174 Split responsibilities

175 Component composition

176 Layer-4 architecture

177 Service lifecycle

178 Startup sequence

179 Shutdown sequence

180 System ownership graph

---

# Part XI
# Complete Systems

## Chapter 19 — Walkthroughs

181 Echo service

182 Chat server

183 Job queue

184 Thread pool replacement

185 Resource manager

186 Timer service

187 File processing pipeline

188 Video transcoder

189 Network service

190 Complete modular monolith

---

# Part XII
# Design

## Chapter 20 — Best Practices

191 Why Slot exists

192 Why intrusive lists

193 Why PolyNode

194 Why ownership transfer

195 Why Pools

196 Why Futures

197 Why Io.Group

198 Why Io.Select

199 Why Matryoshka

200 Building your own architecture

---

# Recipe format

Every recipe uses exactly the same structure.

```
Recipe XXX — Title

Problem

Why this problem exists.

Solution

The Matryoshka solution.

Ingredients

Required components.

Prerequisites

Recipes to read first.

Patterns

Related implementation patterns.

API

Relevant API reference sections.

Source Example

Existing example(s).

Discussion

Design rationale.

Common Mistakes

Typical errors.

Next Recipes

Suggested continuation.
```

---

# Book progression

The reader can stop after any part.

Part I teaches ownership.

Part II teaches runtime polymorphism.

Part III teaches communication.

Part IV teaches resource management.

Part V introduces asynchronous waiting.

Part VI introduces worker execution.

Part VII introduces event-driven programming.

Part VIII explains cancellation.

Part IX explains backpressure.

Part X builds reusable architectures.

Part XI presents complete real-world systems.

Part XII explains the design philosophy behind Matryoshka.
