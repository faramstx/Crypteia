;; Crypteia - Secure Messaging Smart Contract
;; Named after Spartan guardians of secrecy

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-message (err u101))
(define-constant err-message-not-found (err u102))
(define-constant err-invalid-hash (err u103))
(define-constant err-invalid-recipient (err u104))
(define-constant err-already-signed (err u105))
(define-constant err-insufficient-signatures (err u106))
(define-constant err-invalid-threshold (err u107))
(define-constant err-max-signers-exceeded (err u108))
(define-constant err-group-not-found (err u109))
(define-constant err-not-group-member (err u110))
(define-constant err-invalid-group-size (err u111))
(define-constant err-key-rotation-failed (err u112))

;; Data Variables
(define-data-var total-messages uint u0)
(define-data-var total-multisig-messages uint u0)
(define-data-var total-group-chats uint u0)
(define-data-var contract-version uint u3)
(define-constant max-signers u10)
(define-constant max-group-members u20)

;; Data Maps
(define-map messages
  { message-id: uint }
  {
    sender: principal,
    recipient: principal,
    message-hash: (buff 32),
    timestamp: uint,
    block-height: uint,
    verified: bool
  }
)

(define-map multisig-messages
  { multisig-id: uint }
  {
    creator: principal,
    message-hash: (buff 32),
    required-signatures: uint,
    current-signatures: uint,
    timestamp: uint,
    block-height: uint,
    completed: bool
  }
)

(define-map multisig-signers
  { multisig-id: uint, signer: principal }
  { signed: bool, signature-timestamp: uint }
)

(define-map multisig-authorized-signers
  { multisig-id: uint }
  { signers: (list 10 principal) }
)

(define-map group-chats
  { group-id: uint }
  {
    creator: principal,
    group-name: (string-ascii 64),
    created-at: uint,
    block-height: uint,
    active: bool,
    current-key-version: uint,
    member-count: uint
  }
)

(define-map group-members
  { group-id: uint }
  { members: (list 20 principal) }
)

(define-map group-messages
  { group-id: uint, message-index: uint }
  {
    sender: principal,
    message-hash: (buff 32),
    timestamp: uint,
    block-height: uint,
    key-version: uint
  }
)

(define-map group-message-count
  { group-id: uint }
  { count: uint }
)

(define-map group-key-rotations
  { group-id: uint, key-version: uint }
  {
    rotated-by: principal,
    rotation-timestamp: uint,
    rotation-block: uint
  }
)

(define-map user-groups
  { user: principal, group-id: uint }
  { is-member: bool, joined-at: uint }
)

(define-map user-message-count
  { user: principal }
  { count: uint }
)

(define-map message-verification
  { message-hash: (buff 32) }
  { 
    message-id: uint,
    verification-count: uint
  }
)

;; Private Functions
(define-private (is-valid-hash (hash (buff 32)))
  (> (len hash) u0)
)

(define-private (is-valid-principal (user principal))
  (not (is-eq user 'SP000000000000000000002Q6VF78))
)

(define-private (increment-user-count (user principal))
  (let ((current-count (default-to u0 (get count (map-get? user-message-count { user: user })))))
    (ok (map-set user-message-count 
      { user: user }
      { count: (+ current-count u1) }
    ))
  )
)

(define-private (is-authorized-signer (multisig-id uint) (signer principal))
  (let ((authorized-data (map-get? multisig-authorized-signers { multisig-id: multisig-id })))
    (match authorized-data
      signers-data (is-some (index-of (get signers signers-data) signer))
      false
    )
  )
)

(define-private (has-already-signed (multisig-id uint) (signer principal))
  (let ((signer-data (map-get? multisig-signers { multisig-id: multisig-id, signer: signer })))
    (match signer-data
      data (get signed data)
      false
    )
  )
)

(define-private (is-group-member (group-id uint) (user principal))
  (let ((member-data (map-get? user-groups { user: user, group-id: group-id })))
    (match member-data
      data (get is-member data)
      false
    )
  )
)

(define-private (check-valid-principal (principal-to-check principal) (acc bool))
  (and acc (is-valid-principal principal-to-check))
)

(define-private (is-valid-group-name (name (string-ascii 64)))
  (and (> (len name) u0) (<= (len name) u64))
)

;; Public Functions

;; Send encrypted message with on-chain footprint
(define-public (send-message (recipient principal) (message-hash (buff 32)))
  (let 
    (
      (message-id (+ (var-get total-messages) u1))
      (current-block stacks-block-height)
    )
    ;; Validate inputs
    (asserts! (is-valid-principal recipient) err-invalid-recipient)
    (asserts! (is-valid-hash message-hash) err-invalid-hash)
    (asserts! (not (is-eq tx-sender recipient)) err-unauthorized)
    
    ;; Store message metadata
    (map-set messages
      { message-id: message-id }
      {
        sender: tx-sender,
        recipient: recipient,
        message-hash: message-hash,
        timestamp: stacks-block-height,
        block-height: current-block,
        verified: false
      }
    )
    
    ;; Update verification map
    (map-set message-verification
      { message-hash: message-hash }
      {
        message-id: message-id,
        verification-count: u1
      }
    )
    
    ;; Update counters
    (var-set total-messages message-id)
    (unwrap-panic (increment-user-count tx-sender))
    
    ;; Return message ID
    (ok message-id)
  )
)

;; Create multi-signature message
(define-public (create-multisig-message 
  (message-hash (buff 32)) 
  (required-signatures uint) 
  (authorized-signers (list 10 principal)))
  (let 
    (
      (multisig-id (+ (var-get total-multisig-messages) u1))
      (current-block stacks-block-height)
      (signers-count (len authorized-signers))
    )
    ;; Validate inputs
    (asserts! (is-valid-hash message-hash) err-invalid-hash)
    (asserts! (> required-signatures u0) err-invalid-threshold)
    (asserts! (<= required-signatures signers-count) err-invalid-threshold)
    (asserts! (<= signers-count max-signers) err-max-signers-exceeded)
    (asserts! (> signers-count u0) err-invalid-threshold)
    
    ;; Ensure all signers are valid principals
    (asserts! (fold check-valid-principal authorized-signers true) err-invalid-recipient)
    
    ;; Store multisig message
    (map-set multisig-messages
      { multisig-id: multisig-id }
      {
        creator: tx-sender,
        message-hash: message-hash,
        required-signatures: required-signatures,
        current-signatures: u0,
        timestamp: stacks-block-height,
        block-height: current-block,
        completed: false
      }
    )
    
    ;; Store authorized signers
    (map-set multisig-authorized-signers
      { multisig-id: multisig-id }
      { signers: authorized-signers }
    )
    
    ;; Update counter
    (var-set total-multisig-messages multisig-id)
    (unwrap-panic (increment-user-count tx-sender))
    
    (ok multisig-id)
  )
)

;; Sign a multi-signature message
(define-public (sign-multisig-message (multisig-id uint))
  (let 
    (
      (multisig-data (unwrap! (map-get? multisig-messages { multisig-id: multisig-id }) err-message-not-found))
      (current-signatures (get current-signatures multisig-data))
      (required-signatures (get required-signatures multisig-data))
      (completed (get completed multisig-data))
    )
    ;; Validate inputs
    (asserts! (> multisig-id u0) err-invalid-message)
    (asserts! (not completed) err-unauthorized)
    (asserts! (is-authorized-signer multisig-id tx-sender) err-unauthorized)
    (asserts! (not (has-already-signed multisig-id tx-sender)) err-already-signed)
    
    ;; Record signature
    (map-set multisig-signers
      { multisig-id: multisig-id, signer: tx-sender }
      { signed: true, signature-timestamp: stacks-block-height }
    )
    
    ;; Update signature count
    (let ((new-signature-count (+ current-signatures u1)))
      (map-set multisig-messages
        { multisig-id: multisig-id }
        (merge multisig-data { 
          current-signatures: new-signature-count,
          completed: (>= new-signature-count required-signatures)
        })
      )
      
      (ok new-signature-count)
    )
  )
)

;; Create encrypted group chat
(define-public (create-group-chat 
  (group-name (string-ascii 64))
  (members (list 20 principal)))
  (let
    (
      (group-id (+ (var-get total-group-chats) u1))
      (current-block stacks-block-height)
      (members-count (len members))
    )
    ;; Validate inputs
    (asserts! (is-valid-group-name group-name) err-invalid-message)
    (asserts! (> members-count u1) err-invalid-group-size)
    (asserts! (<= members-count max-group-members) err-invalid-group-size)
    (asserts! (fold check-valid-principal members true) err-invalid-recipient)
    
    ;; Store group chat
    (map-set group-chats
      { group-id: group-id }
      {
        creator: tx-sender,
        group-name: group-name,
        created-at: stacks-block-height,
        block-height: current-block,
        active: true,
        current-key-version: u1,
        member-count: members-count
      }
    )
    
    ;; Store group members
    (map-set group-members
      { group-id: group-id }
      { members: members }
    )
    
    ;; Initialize message count
    (map-set group-message-count
      { group-id: group-id }
      { count: u0 }
    )
    
    ;; Initialize key rotation
    (map-set group-key-rotations
      { group-id: group-id, key-version: u1 }
      {
        rotated-by: tx-sender,
        rotation-timestamp: stacks-block-height,
        rotation-block: current-block
      }
    )
    
    ;; Add all members to user-groups map
    (add-members-to-group group-id members stacks-block-height)
    
    ;; Update counters
    (var-set total-group-chats group-id)
    (unwrap-panic (increment-user-count tx-sender))
    
    (ok group-id)
  )
)

;; Helper function to add members to group
(define-private (add-members-to-group (group-id uint) (members (list 20 principal)) (timestamp uint))
  (fold add-single-member members { group-id: group-id, timestamp: timestamp, success: true })
)

;; Helper to add a single member
(define-private (add-single-member 
  (member principal) 
  (context { group-id: uint, timestamp: uint, success: bool }))
  (begin
    (map-set user-groups
      { user: member, group-id: (get group-id context) }
      { is-member: true, joined-at: (get timestamp context) }
    )
    context
  )
)

;; Send message to group chat
(define-public (send-group-message (group-id uint) (message-hash (buff 32)))
  (let
    (
      (group-data (unwrap! (map-get? group-chats { group-id: group-id }) err-group-not-found))
      (message-count-data (unwrap! (map-get? group-message-count { group-id: group-id }) err-group-not-found))
      (current-count (get count message-count-data))
      (new-message-index (+ current-count u1))
      (current-block stacks-block-height)
      (current-key-version (get current-key-version group-data))
      (is-active (get active group-data))
    )
    ;; Validate inputs
    (asserts! (> group-id u0) err-invalid-message)
    (asserts! (is-valid-hash message-hash) err-invalid-hash)
    (asserts! is-active err-unauthorized)
    (asserts! (is-group-member group-id tx-sender) err-not-group-member)
    
    ;; Store group message
    (map-set group-messages
      { group-id: group-id, message-index: new-message-index }
      {
        sender: tx-sender,
        message-hash: message-hash,
        timestamp: stacks-block-height,
        block-height: current-block,
        key-version: current-key-version
      }
    )
    
    ;; Update message count
    (map-set group-message-count
      { group-id: group-id }
      { count: new-message-index }
    )
    
    ;; Update user count
    (unwrap-panic (increment-user-count tx-sender))
    
    (ok new-message-index)
  )
)

;; Rotate group encryption key
(define-public (rotate-group-key (group-id uint))
  (let
    (
      (group-data (unwrap! (map-get? group-chats { group-id: group-id }) err-group-not-found))
      (current-key-version (get current-key-version group-data))
      (new-key-version (+ current-key-version u1))
      (current-block stacks-block-height)
      (is-active (get active group-data))
    )
    ;; Validate inputs
    (asserts! (> group-id u0) err-invalid-message)
    (asserts! is-active err-unauthorized)
    (asserts! (is-group-member group-id tx-sender) err-not-group-member)
    
    ;; Update group with new key version
    (map-set group-chats
      { group-id: group-id }
      (merge group-data { current-key-version: new-key-version })
    )
    
    ;; Record key rotation
    (map-set group-key-rotations
      { group-id: group-id, key-version: new-key-version }
      {
        rotated-by: tx-sender,
        rotation-timestamp: stacks-block-height,
        rotation-block: current-block
      }
    )
    
    (ok new-key-version)
  )
)

;; Verify message integrity
(define-public (verify-message (message-id uint) (provided-hash (buff 32)))
  (let 
    (
      (message-data (unwrap! (map-get? messages { message-id: message-id }) err-message-not-found))
      (stored-hash (get message-hash message-data))
    )
    ;; Validate inputs
    (asserts! (is-valid-hash provided-hash) err-invalid-hash)
    (asserts! (> message-id u0) err-invalid-message)
    
    ;; Check if hashes match
    (if (is-eq stored-hash provided-hash)
      (begin
        ;; Mark as verified
        (map-set messages
          { message-id: message-id }
          (merge message-data { verified: true })
        )
        ;; Update verification count
        (let ((current-verification (default-to { message-id: u0, verification-count: u0 } 
                                               (map-get? message-verification { message-hash: provided-hash }))))
          (map-set message-verification
            { message-hash: provided-hash }
            {
              message-id: message-id,
              verification-count: (+ (get verification-count current-verification) u1)
            }
          )
        )
        (ok true)
      )
      (ok false)
    )
  )
)

;; Read-only Functions

;; Get message information
(define-read-only (get-message-info (message-id uint))
  (begin
    (asserts! (> message-id u0) err-invalid-message)
    (ok (map-get? messages { message-id: message-id }))
  )
)

;; Get multisig message information
(define-read-only (get-multisig-info (multisig-id uint))
  (begin
    (asserts! (> multisig-id u0) err-invalid-message)
    (ok (map-get? multisig-messages { multisig-id: multisig-id }))
  )
)

;; Get multisig authorized signers
(define-read-only (get-multisig-signers (multisig-id uint))
  (begin
    (asserts! (> multisig-id u0) err-invalid-message)
    (ok (map-get? multisig-authorized-signers { multisig-id: multisig-id }))
  )
)

;; Check if user has signed multisig message
(define-read-only (has-user-signed (multisig-id uint) (user principal))
  (begin
    (asserts! (> multisig-id u0) err-invalid-message)
    (asserts! (is-valid-principal user) err-invalid-recipient)
    (ok (has-already-signed multisig-id user))
  )
)

;; Get group chat information
(define-read-only (get-group-info (group-id uint))
  (begin
    (asserts! (> group-id u0) err-invalid-message)
    (ok (map-get? group-chats { group-id: group-id }))
  )
)

;; Get group members
(define-read-only (get-group-members (group-id uint))
  (begin
    (asserts! (> group-id u0) err-invalid-message)
    (ok (map-get? group-members { group-id: group-id }))
  )
)

;; Get group message
(define-read-only (get-group-message (group-id uint) (message-index uint))
  (begin
    (asserts! (> group-id u0) err-invalid-message)
    (asserts! (> message-index u0) err-invalid-message)
    (ok (map-get? group-messages { group-id: group-id, message-index: message-index }))
  )
)

;; Get group message count
(define-read-only (get-group-message-count (group-id uint))
  (begin
    (asserts! (> group-id u0) err-invalid-message)
    (ok (default-to u0 (get count (map-get? group-message-count { group-id: group-id }))))
  )
)

;; Check if user is group member
(define-read-only (is-user-group-member (group-id uint) (user principal))
  (begin
    (asserts! (> group-id u0) err-invalid-message)
    (asserts! (is-valid-principal user) err-invalid-recipient)
    (ok (is-group-member group-id user))
  )
)

;; Get key rotation info
(define-read-only (get-key-rotation-info (group-id uint) (key-version uint))
  (begin
    (asserts! (> group-id u0) err-invalid-message)
    (asserts! (> key-version u0) err-invalid-message)
    (ok (map-get? group-key-rotations { group-id: group-id, key-version: key-version }))
  )
)

;; Get messages sent by user
(define-read-only (get-user-message-count (user principal))
  (begin
    (asserts! (is-valid-principal user) err-invalid-recipient)
    (ok (default-to u0 (get count (map-get? user-message-count { user: user }))))
  )
)

;; Get total messages in system
(define-read-only (get-total-messages)
  (ok (var-get total-messages))
)

;; Get total multisig messages
(define-read-only (get-total-multisig-messages)
  (ok (var-get total-multisig-messages))
)

;; Get total group chats
(define-read-only (get-total-group-chats)
  (ok (var-get total-group-chats))
)

;; Get contract version
(define-read-only (get-contract-version)
  (ok (var-get contract-version))
)

;; Check if message hash exists
(define-read-only (message-hash-exists (hash (buff 32)))
  (begin
    (asserts! (is-valid-hash hash) err-invalid-hash)
    (ok (is-some (map-get? message-verification { message-hash: hash })))
  )
)

;; Get verification count for hash
(define-read-only (get-verification-count (hash (buff 32)))
  (begin
    (asserts! (is-valid-hash hash) err-invalid-hash)
    (ok (default-to u0 (get verification-count (map-get? message-verification { message-hash: hash }))))
  )
)

;; Admin function to update contract version (owner only)
(define-public (update-contract-version (new-version uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (> new-version (var-get contract-version)) err-invalid-message)
    (var-set contract-version new-version)
    (ok true)
  )
)