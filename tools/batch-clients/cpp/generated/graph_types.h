/**
 * Autogenerated by Thrift Compiler (0.9.0)
 *
 * DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
 *  @generated
 */
#ifndef graph_TYPES_H
#define graph_TYPES_H

#include <thrift/Thrift.h>
#include <thrift/TApplicationException.h>
#include <thrift/protocol/TProtocol.h>
#include <thrift/transport/TTransport.h>

#include "attrs_types.h"


namespace flowbox { namespace batch { namespace graph {

struct NodeType {
  enum type {
    Expr = 0,
    Default = 1,
    Inputs = 2,
    Outputs = 3,
    Tuple = 4
  };
};

extern const std::map<int, const char*> _NodeType_VALUES_TO_NAMES;

struct PortType {
  enum type {
    All = 0,
    Number = 1
  };
};

extern const std::map<int, const char*> _PortType_VALUES_TO_NAMES;

typedef int32_t NodeID;

typedef struct _Value__isset {
  _Value__isset() : value(false) {}
  bool value;
} _Value__isset;

class Value {
 public:

  static const char* ascii_fingerprint; // = "E8C48C1156CEFB2CC2155B26B71AB9E0";
  static const uint8_t binary_fingerprint[16]; // = {0xE8,0xC4,0x8C,0x11,0x56,0xCE,0xFB,0x2C,0xC2,0x15,0x5B,0x26,0xB7,0x1A,0xB9,0xE0};

  Value() : value() {
  }

  virtual ~Value() throw() {}

  std::string value;

  _Value__isset __isset;

  void __set_value(const std::string& val) {
    value = val;
    __isset.value = true;
  }

  bool operator == (const Value & rhs) const
  {
    if (__isset.value != rhs.__isset.value)
      return false;
    else if (__isset.value && !(value == rhs.value))
      return false;
    return true;
  }
  bool operator != (const Value &rhs) const {
    return !(*this == rhs);
  }

  bool operator < (const Value & ) const;

  uint32_t read(::apache::thrift::protocol::TProtocol* iprot);
  uint32_t write(::apache::thrift::protocol::TProtocol* oprot) const;

};

void swap(Value &a, Value &b);

typedef struct _Node__isset {
  _Node__isset() : cls(false), expression(true), nodeID(true), flags(true), attrs(true), value(true) {}
  bool cls;
  bool expression;
  bool nodeID;
  bool flags;
  bool attrs;
  bool value;
} _Node__isset;

class Node {
 public:

  static const char* ascii_fingerprint; // = "32315F6108A039695C6BD4ECE22E0DF0";
  static const uint8_t binary_fingerprint[16]; // = {0x32,0x31,0x5F,0x61,0x08,0xA0,0x39,0x69,0x5C,0x6B,0xD4,0xEC,0xE2,0x2E,0x0D,0xF0};

  Node() : cls((NodeType::type)0), expression(""), nodeID(-1) {



  }

  virtual ~Node() throw() {}

  NodeType::type cls;
  std::string expression;
  NodeID nodeID;
   ::flowbox::batch::attrs::Flags flags;
   ::flowbox::batch::attrs::Attributes attrs;
  Value value;

  _Node__isset __isset;

  void __set_cls(const NodeType::type val) {
    cls = val;
    __isset.cls = true;
  }

  void __set_expression(const std::string& val) {
    expression = val;
    __isset.expression = true;
  }

  void __set_nodeID(const NodeID val) {
    nodeID = val;
    __isset.nodeID = true;
  }

  void __set_flags(const  ::flowbox::batch::attrs::Flags& val) {
    flags = val;
    __isset.flags = true;
  }

  void __set_attrs(const  ::flowbox::batch::attrs::Attributes& val) {
    attrs = val;
    __isset.attrs = true;
  }

  void __set_value(const Value& val) {
    value = val;
    __isset.value = true;
  }

  bool operator == (const Node & rhs) const
  {
    if (__isset.cls != rhs.__isset.cls)
      return false;
    else if (__isset.cls && !(cls == rhs.cls))
      return false;
    if (__isset.expression != rhs.__isset.expression)
      return false;
    else if (__isset.expression && !(expression == rhs.expression))
      return false;
    if (__isset.nodeID != rhs.__isset.nodeID)
      return false;
    else if (__isset.nodeID && !(nodeID == rhs.nodeID))
      return false;
    if (__isset.flags != rhs.__isset.flags)
      return false;
    else if (__isset.flags && !(flags == rhs.flags))
      return false;
    if (__isset.attrs != rhs.__isset.attrs)
      return false;
    else if (__isset.attrs && !(attrs == rhs.attrs))
      return false;
    if (__isset.value != rhs.__isset.value)
      return false;
    else if (__isset.value && !(value == rhs.value))
      return false;
    return true;
  }
  bool operator != (const Node &rhs) const {
    return !(*this == rhs);
  }

  bool operator < (const Node & ) const;

  uint32_t read(::apache::thrift::protocol::TProtocol* iprot);
  uint32_t write(::apache::thrift::protocol::TProtocol* oprot) const;

};

void swap(Node &a, Node &b);

typedef struct _Port__isset {
  _Port__isset() : cls(false), number(false) {}
  bool cls;
  bool number;
} _Port__isset;

class Port {
 public:

  static const char* ascii_fingerprint; // = "75971A588272C97A80EBFD5BA7E9F503";
  static const uint8_t binary_fingerprint[16]; // = {0x75,0x97,0x1A,0x58,0x82,0x72,0xC9,0x7A,0x80,0xEB,0xFD,0x5B,0xA7,0xE9,0xF5,0x03};

  Port() : cls((PortType::type)0), number(0) {
  }

  virtual ~Port() throw() {}

  PortType::type cls;
  int32_t number;

  _Port__isset __isset;

  void __set_cls(const PortType::type val) {
    cls = val;
    __isset.cls = true;
  }

  void __set_number(const int32_t val) {
    number = val;
    __isset.number = true;
  }

  bool operator == (const Port & rhs) const
  {
    if (__isset.cls != rhs.__isset.cls)
      return false;
    else if (__isset.cls && !(cls == rhs.cls))
      return false;
    if (__isset.number != rhs.__isset.number)
      return false;
    else if (__isset.number && !(number == rhs.number))
      return false;
    return true;
  }
  bool operator != (const Port &rhs) const {
    return !(*this == rhs);
  }

  bool operator < (const Port & ) const;

  uint32_t read(::apache::thrift::protocol::TProtocol* iprot);
  uint32_t write(::apache::thrift::protocol::TProtocol* oprot) const;

};

void swap(Port &a, Port &b);

typedef struct _Edge__isset {
  _Edge__isset() : nodeSrc(false), nodeDst(false), portSrc(false), portDst(false) {}
  bool nodeSrc;
  bool nodeDst;
  bool portSrc;
  bool portDst;
} _Edge__isset;

class Edge {
 public:

  static const char* ascii_fingerprint; // = "1B1D429E9E864B4725E72BF8E70DB698";
  static const uint8_t binary_fingerprint[16]; // = {0x1B,0x1D,0x42,0x9E,0x9E,0x86,0x4B,0x47,0x25,0xE7,0x2B,0xF8,0xE7,0x0D,0xB6,0x98};

  Edge() : nodeSrc(0), nodeDst(0) {
  }

  virtual ~Edge() throw() {}

  NodeID nodeSrc;
  NodeID nodeDst;
  Port portSrc;
  Port portDst;

  _Edge__isset __isset;

  void __set_nodeSrc(const NodeID val) {
    nodeSrc = val;
    __isset.nodeSrc = true;
  }

  void __set_nodeDst(const NodeID val) {
    nodeDst = val;
    __isset.nodeDst = true;
  }

  void __set_portSrc(const Port& val) {
    portSrc = val;
    __isset.portSrc = true;
  }

  void __set_portDst(const Port& val) {
    portDst = val;
    __isset.portDst = true;
  }

  bool operator == (const Edge & rhs) const
  {
    if (__isset.nodeSrc != rhs.__isset.nodeSrc)
      return false;
    else if (__isset.nodeSrc && !(nodeSrc == rhs.nodeSrc))
      return false;
    if (__isset.nodeDst != rhs.__isset.nodeDst)
      return false;
    else if (__isset.nodeDst && !(nodeDst == rhs.nodeDst))
      return false;
    if (__isset.portSrc != rhs.__isset.portSrc)
      return false;
    else if (__isset.portSrc && !(portSrc == rhs.portSrc))
      return false;
    if (__isset.portDst != rhs.__isset.portDst)
      return false;
    else if (__isset.portDst && !(portDst == rhs.portDst))
      return false;
    return true;
  }
  bool operator != (const Edge &rhs) const {
    return !(*this == rhs);
  }

  bool operator < (const Edge & ) const;

  uint32_t read(::apache::thrift::protocol::TProtocol* iprot);
  uint32_t write(::apache::thrift::protocol::TProtocol* oprot) const;

};

void swap(Edge &a, Edge &b);

typedef struct _Graph__isset {
  _Graph__isset() : nodes(false), edges(false) {}
  bool nodes;
  bool edges;
} _Graph__isset;

class Graph {
 public:

  static const char* ascii_fingerprint; // = "61E77B47035104B90899734D6AC145D5";
  static const uint8_t binary_fingerprint[16]; // = {0x61,0xE7,0x7B,0x47,0x03,0x51,0x04,0xB9,0x08,0x99,0x73,0x4D,0x6A,0xC1,0x45,0xD5};

  Graph() {
  }

  virtual ~Graph() throw() {}

  std::map<NodeID, Node>  nodes;
  std::vector<Edge>  edges;

  _Graph__isset __isset;

  void __set_nodes(const std::map<NodeID, Node> & val) {
    nodes = val;
    __isset.nodes = true;
  }

  void __set_edges(const std::vector<Edge> & val) {
    edges = val;
    __isset.edges = true;
  }

  bool operator == (const Graph & rhs) const
  {
    if (__isset.nodes != rhs.__isset.nodes)
      return false;
    else if (__isset.nodes && !(nodes == rhs.nodes))
      return false;
    if (__isset.edges != rhs.__isset.edges)
      return false;
    else if (__isset.edges && !(edges == rhs.edges))
      return false;
    return true;
  }
  bool operator != (const Graph &rhs) const {
    return !(*this == rhs);
  }

  bool operator < (const Graph & ) const;

  uint32_t read(::apache::thrift::protocol::TProtocol* iprot);
  uint32_t write(::apache::thrift::protocol::TProtocol* oprot) const;

};

void swap(Graph &a, Graph &b);

}}} // namespace

#endif
