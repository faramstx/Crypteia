;; Crypteia - Secure Messaging Smart Contract
;; Named after Spartan guardians of secrecy

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-message (err u101))
(define-constant err-message-not-found (err u102))
(define-constant err-invalid-hash (err u103))
(define-constant err-invalid-recipient (err u104))

;; Data Variables
(define-data-var total-messages uint u0)
(define-data-var contract-version uint u1)

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
        timestamp: current-block,
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

;; Get message information
(define-read-only (get-message-info (message-id uint))
  (begin
    (asserts! (> message-id u0) err-invalid-message)
    (ok (map-get? messages { message-id: message-id }))
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