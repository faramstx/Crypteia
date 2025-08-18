import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can send message with valid parameters",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        const user2 = accounts.get('wallet_2')!;
        
        const messageHash = new Uint8Array(32).fill(1); // Valid 32-byte hash
        
        let block = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'send-message', [
                types.principal(user2.address),
                types.buff(messageHash)
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), 'u1');
    },
});

Clarinet.test({
    name: "Cannot send message to self",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get('wallet_1')!;
        const messageHash = new Uint8Array(32).fill(1);
        
        let block = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'send-message', [
                types.principal(user1.address),
                types.buff(messageHash)
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectErr().expectUint(100); // err-unauthorized
    },
});

Clarinet.test({
    name: "Cannot send message with invalid hash",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get('wallet_1')!;
        const user2 = accounts.get('wallet_2')!;
        const emptyHash = new Uint8Array(0); // Invalid empty hash
        
        let block = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'send-message', [
                types.principal(user2.address),
                types.buff(emptyHash)
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectErr().expectUint(103); // err-invalid-hash
    },
});

Clarinet.test({
    name: "Can verify message with correct hash",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get('wallet_1')!;
        const user2 = accounts.get('wallet_2')!;
        const messageHash = new Uint8Array(32).fill(1);
        
        // Send message first
        let block = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'send-message', [
                types.principal(user2.address),
                types.buff(messageHash)
            ], user1.address)
        ]);
        
        // Verify message
        let verifyBlock = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'verify-message', [
                types.uint(1),
                types.buff(messageHash)
            ], user1.address)
        ]);
        
        assertEquals(verifyBlock.receipts.length, 1);
        assertEquals(verifyBlock.receipts[0].result.expectOk(), 'true');
    },
});

Clarinet.test({
    name: "Message verification fails with wrong hash",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get('wallet_1')!;
        const user2 = accounts.get('wallet_2')!;
        const messageHash = new Uint8Array(32).fill(1);
        const wrongHash = new Uint8Array(32).fill(2);
        
        // Send message first
        let block = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'send-message', [
                types.principal(user2.address),
                types.buff(messageHash)
            ], user1.address)
        ]);
        
        // Try to verify with wrong hash
        let verifyBlock = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'verify-message', [
                types.uint(1),
                types.buff(wrongHash)
            ], user1.address)
        ]);
        
        assertEquals(verifyBlock.receipts.length, 1);
        assertEquals(verifyBlock.receipts[0].result.expectOk(), 'false');
    },
});

Clarinet.test({
    name: "Can get message info",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get('wallet_1')!;
        const user2 = accounts.get('wallet_2')!;
        const messageHash = new Uint8Array(32).fill(1);
        
        // Send message first
        let block = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'send-message', [
                types.principal(user2.address),
                types.buff(messageHash)
            ], user1.address)
        ]);
        
        // Get message info
        let infoBlock = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'get-message-info', [
                types.uint(1)
            ], user1.address)
        ]);
        
        assertEquals(infoBlock.receipts.length, 1);
        const result = infoBlock.receipts[0].result.expectOk();
        assertEquals(result.expectSome()['sender'], user1.address);
        assertEquals(result.expectSome()['recipient'], user2.address);
    },
});

Clarinet.test({
    name: "User message count increments correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get('wallet_1')!;
        const user2 = accounts.get('wallet_2')!;
        const messageHash1 = new Uint8Array(32).fill(1);
        const messageHash2 = new Uint8Array(32).fill(2);
        
        // Send first message
        let block1 = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'send-message', [
                types.principal(user2.address),
                types.buff(messageHash1)
            ], user1.address)
        ]);
        
        // Check count after first message
        let countBlock1 = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'get-user-message-count', [
                types.principal(user1.address)
            ], user1.address)
        ]);
        
        assertEquals(countBlock1.receipts[0].result.expectOk(), 'u1');
        
        // Send second message
        let block2 = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'send-message', [
                types.principal(user2.address),
                types.buff(messageHash2)
            ], user1.address)
        ]);
        
        // Check count after second message
        let countBlock2 = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'get-user-message-count', [
                types.principal(user1.address)
            ], user1.address)
        ]);
        
        assertEquals(countBlock2.receipts[0].result.expectOk(), 'u2');
    },
});

Clarinet.test({
    name: "Message hash exists check works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get('wallet_1')!;
        const user2 = accounts.get('wallet_2')!;
        const messageHash = new Uint8Array(32).fill(1);
        const nonExistentHash = new Uint8Array(32).fill(99);
        
        // Check non-existent hash
        let checkBlock1 = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'message-hash-exists', [
                types.buff(nonExistentHash)
            ], user1.address)
        ]);
        
        assertEquals(checkBlock1.receipts[0].result.expectOk(), 'false');
        
        // Send message
        let block = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'send-message', [
                types.principal(user2.address),
                types.buff(messageHash)
            ], user1.address)
        ]);
        
        // Check existing hash
        let checkBlock2 = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'message-hash-exists', [
                types.buff(messageHash)
            ], user1.address)
        ]);
        
        assertEquals(checkBlock2.receipts[0].result.expectOk(), 'true');
    },
});

Clarinet.test({
    name: "Only contract owner can update version",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        // Non-owner tries to update version
        let block1 = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'update-contract-version', [
                types.uint(2)
            ], user1.address)
        ]);
        
        assertEquals(block1.receipts.length, 1);
        block1.receipts[0].result.expectErr().expectUint(100); // err-unauthorized
        
        // Owner updates version
        let block2 = chain.mineBlock([
            Tx.contractCall('crypteia-core', 'update-contract-version', [
                types.uint(2)
            ], deployer.address)
        ]);
        
        assertEquals(block2.receipts.length, 1);
        assertEquals(block2.receipts[0].result.expectOk(), 'true');
    },
});