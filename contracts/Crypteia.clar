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

;; Data Variables
(define-data-var total-messages uint u0)
(define-data-var total-multisig-messages uint u0)
(define-data-var contract-version uint u2)
(define-constant max-signers u10)

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
    (map-set user-message-count 
      { user: user }
      { count: (+ current-count u1) }
    )
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
    (increment-user-count tx-sender)
    
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
    (increment-user-count tx-sender)
    
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

;; Helper function for validating principals
(define-private (check-valid-principal (principal-to-check principal) (acc bool))
  (and acc (is-valid-principal principal-to-check))
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