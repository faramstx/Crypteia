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
- **Multi-Signature Messages**: Require multiple signatures to decrypt sensitive communications
- **Group Chat Encryption**: End-to-end encrypted group conversations with key rotation

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

### Standard Messages
- `send-message`: Creates encrypted message footprint
- `verify-message`: Validates message integrity
- `get-message-info`: Retrieves on-chain metadata

### Multi-Signature Messages
- `create-multisig-message`: Creates a message requiring multiple signatures
- `sign-multisig-message`: Signs a multi-signature message
- `get-multisig-info`: Retrieves multi-signature message details
- `get-multisig-signers`: Gets authorized signers for a message
- `has-user-signed`: Checks if a user has signed a specific message

### Group Chat Functions
- `create-group-chat`: Creates an encrypted group chat with up to 20 members
- `send-group-message`: Sends an encrypted message to a group
- `rotate-group-key`: Rotates the encryption key for enhanced security
- `get-group-info`: Retrieves group chat metadata
- `get-group-members`: Gets list of group members
- `get-group-message`: Retrieves a specific group message
- `get-group-message-count`: Gets total messages in a group
- `is-user-group-member`: Checks if a user is a member of a group
- `get-key-rotation-info`: Gets information about key rotation events

## Multi-Signature Workflow

1. **Create**: Initiate a multi-sig message with required signature threshold
2. **Authorize**: Define list of authorized signers (up to 10)
3. **Sign**: Authorized parties sign the message individually
4. **Complete**: Message becomes accessible once threshold is met

## Group Chat Workflow

1. **Create Group**: Initialize a group chat with a name and up to 20 members
2. **Send Messages**: Members send encrypted messages to the group
3. **Key Rotation**: Any member can rotate the encryption key for forward secrecy
4. **Message History**: All messages are timestamped and linked to key versions

### Group Chat Security Features

- **Forward Secrecy**: Key rotation ensures past messages remain secure even if current keys are compromised
- **Member Verification**: All members are validated and tracked on-chain
- **Key Version Tracking**: Each message is linked to a specific key version
- **Immutable Audit Trail**: All key rotations are recorded with timestamp and initiator

## Security Considerations

- Messages are encrypted client-side before any blockchain interaction
- Private keys never leave the user's device
- Only cryptographic hashes and timestamps are stored on-chain
- Multi-signature messages require consensus from authorized parties
- Maximum of 10 authorized signers per multi-signature message
- Group chats support up to 20 members with automatic key rotation
- Key rotation provides forward secrecy for group conversations
- Each key rotation is permanently recorded on-chain for transparency
