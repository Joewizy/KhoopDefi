// SolyTicket deployed at: 0xE91F90806918d7C9217Dc9D97b7Bb58fE807aa19
export const forwarderAddress = 0xba27530cf7e3ae3a0d06C4d53781dF0Fe9A5db5c
export const forwarderAbi = [
  {
    type: "constructor",
    inputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "eip712Domain",
    inputs: [],
    outputs: [
      { name: "fields", type: "bytes1" },
      { name: "name", type: "string" },
      { name: "version", type: "string" },
      { name: "chainId", type: "uint256" },
      { name: "verifyingContract", type: "address" },
      { name: "salt", type: "bytes32" },
      { name: "extensions", type: "uint256[]" }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "execute",
    inputs: [
      {
        name: "req",
        type: "tuple",
        components: [
          { name: "from", type: "address" },
          { name: "to", type: "address" },
          { name: "value", type: "uint256" },
          { name: "gas", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "data", type: "bytes" }
        ]
      },
      {
        name: "signature",
        type: "bytes"
      }
    ],
    outputs: [
      { name: "", type: "bool" },
      { name: "", type: "bytes" }
    ],
    stateMutability: "payable"
  },
  {
    type: "function",
    name: "getNonce",
    inputs: [
      {
        name: "from",
        type: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "verify",
    inputs: [
      {
        name: "req",
        type: "tuple",
        components: [
          { name: "from", type: "address" },
          { name: "to", type: "address" },
          { name: "value", type: "uint256" },
          { name: "gas", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "data", type: "bytes" }
        ]
      },
      {
        name: "signature",
        type: "bytes"
      }
    ],
    outputs: [
      {
        name: "",
        type: "bool"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "event",
    name: "EIP712DomainChanged",
    inputs: [],
    anonymous: false
  },
  {
    type: "error",
    name: "InvalidShortString",
    inputs: []
  },
  {
    type: "error",
    name: "StringTooLong",
    inputs: [
      {
        name: "str",
        type: "string"
      }
    ]
  }
];

