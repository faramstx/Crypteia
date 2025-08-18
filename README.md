# Crypteia

**Secure Messaging on Stacks Blockchain**

Named after the Spartan guardians of secrecy, Crypteia is a secure messaging application built on Stacks that enables encrypted communications with cryptographic footprints on-chain.

## Overview

Crypteia combines blockchain transparency with privacy, creating a digital sanctuary for confidential conversations that demand trust and security. Messages are encrypted end-to-end while maintaining cryptographic proof of integrity and timestamping on the Bitcoin-secured Stacks blockchain.

## Features

- **End-to-End Encryption**: Messages are encrypted before transmission
- **On-Chain Timestamps**: Cryptographic footprints recorded on Stacks
- **Message Integrity**: Blockchain-verified message authenticity
- **Privacy Preserved**: Message contents remain confidential
- **Bitcoin Security**: Inherits Bitcoin's security through Stacks settlement

## Architecture

- **Frontend**: React-based web application
- **Smart Contracts**: Clarity contracts on Stacks blockchain
- **Encryption**: Client-side encryption/decryption
- **Storage**: On-chain metadata, off-chain encrypted content

## Getting Started

### Prerequisites

- Node.js v16 or higher
- Clarinet CLI
- Stacks wallet (Hiro Wallet recommended)

### Installation

```bash
git clone https://github.com/yourusername/crypteia
cd crypteia
npm install
clarinet check
```

### Development

```bash
# Start local development
npm run dev

# Run tests
clarinet test

# Deploy contracts
clarinet deploy
```

## Smart Contract Functions

- `send-message`: Creates encrypted message footprint
- `verify-message`: Validates message integrity
- `get-message-info`: Retrieves on-chain metadata

## Security Considerations

- Messages are encrypted client-side before any blockchain interaction
- Private keys never leave the user's device
- Only cryptographic hashes and timestamps are stored on-chain

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make meaningful commits
4. Submit a pull request

---

*Crypteia: Where privacy meets transparency.*