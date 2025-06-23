(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-status (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-expired (err u106))
(define-constant err-not-expired (err u107))

(define-data-var contract-id-nonce uint u0)

(define-map contracts
  { contract-id: uint }
  {
    client: principal,
    freelancer: principal,
    amount: uint,
    deadline: uint,
    status: (string-ascii 20),
    description: (string-ascii 500),
    created-at: uint,
    completed-at: (optional uint),
    disputed: bool
  }
)

(define-map contract-funds
  { contract-id: uint }
  { amount: uint }
)

(define-map dispute-votes
  { contract-id: uint, voter: principal }
  { vote: (string-ascii 10) }
)

(define-map dispute-counts
  { contract-id: uint }
  { client-votes: uint, freelancer-votes: uint, total-votes: uint }
)

(define-read-only (get-contract (contract-id uint))
  (map-get? contracts { contract-id: contract-id })
)

(define-read-only (get-contract-funds (contract-id uint))
  (map-get? contract-funds { contract-id: contract-id })
)

(define-read-only (get-next-contract-id)
  (var-get contract-id-nonce)
)

(define-read-only (get-dispute-vote (contract-id uint) (voter principal))
  (map-get? dispute-votes { contract-id: contract-id, voter: voter })
)

(define-read-only (get-dispute-counts (contract-id uint))
  (map-get? dispute-counts { contract-id: contract-id })
)

(define-public (create-contract (freelancer principal) (amount uint) (deadline uint) (description (string-ascii 500)))
  (let
    (
      (contract-id (var-get contract-id-nonce))
      (current-block stacks-block-height)
    )
    (asserts! (> amount u0) err-insufficient-funds)
    (asserts! (> deadline current-block) err-invalid-status)
    (asserts! (not (is-eq tx-sender freelancer)) err-unauthorized)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set contracts
      { contract-id: contract-id }
      {
        client: tx-sender,
        freelancer: freelancer,
        amount: amount,
        deadline: deadline,
        status: "active",
        description: description,
        created-at: current-block,
        completed-at: none,
        disputed: false
      }
    )
    
    (map-set contract-funds
      { contract-id: contract-id }
      { amount: amount }
    )
    
    (var-set contract-id-nonce (+ contract-id u1))
    (ok contract-id)
  )
)
(define-public (submit-work (contract-id uint))
  (let
    (
      (contract-data (unwrap! (get-contract contract-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get freelancer contract-data)) err-unauthorized)
    (asserts! (is-eq (get status contract-data) "active") err-invalid-status)
    (asserts! (not (get disputed contract-data)) err-invalid-status)
    
    (map-set contracts
      { contract-id: contract-id }
      (merge contract-data { status: "submitted" })
    )
    (ok true)
  )
)

(define-public (approve-work (contract-id uint))
  (let
    (
      (contract-data (unwrap! (get-contract contract-id) err-not-found))
      (fund-data (unwrap! (get-contract-funds contract-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get client contract-data)) err-unauthorized)
    (asserts! (is-eq (get status contract-data) "submitted") err-invalid-status)
    (asserts! (not (get disputed contract-data)) err-invalid-status)
    
    (try! (as-contract (stx-transfer? (get amount fund-data) tx-sender (get freelancer contract-data))))
    
    (map-set contracts
      { contract-id: contract-id }
      (merge contract-data { 
        status: "completed",
        completed-at: (some stacks-block-height)
      })
    )
    
    (map-delete contract-funds { contract-id: contract-id })
    (ok true)
  )
)
(define-public (reject-work (contract-id uint))
  (let
    (
      (contract-data (unwrap! (get-contract contract-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get client contract-data)) err-unauthorized)
    (asserts! (is-eq (get status contract-data) "submitted") err-invalid-status)
    (asserts! (not (get disputed contract-data)) err-invalid-status)
    
    (map-set contracts
      { contract-id: contract-id }
      (merge contract-data { status: "active" })
    )
    (ok true)
  )
)

(define-public (initiate-dispute (contract-id uint))
  (let
    (
      (contract-data (unwrap! (get-contract contract-id) err-not-found))
    )
    (asserts! (or 
      (is-eq tx-sender (get client contract-data))
      (is-eq tx-sender (get freelancer contract-data))
    ) err-unauthorized)
    (asserts! (or 
      (is-eq (get status contract-data) "active")
      (is-eq (get status contract-data) "submitted")
    ) err-invalid-status)
    (asserts! (not (get disputed contract-data)) err-invalid-status)
    
    (map-set contracts
      { contract-id: contract-id }
      (merge contract-data { 
        disputed: true,
        status: "disputed"
      })
    )
    
    (map-set dispute-counts
      { contract-id: contract-id }
      { client-votes: u0, freelancer-votes: u0, total-votes: u0 }
    )
    (ok true)
  )
)

(define-public (vote-dispute (contract-id uint) (vote-for (string-ascii 10)))
  (let
    (
      (contract-data (unwrap! (get-contract contract-id) err-not-found))
      (current-counts (default-to { client-votes: u0, freelancer-votes: u0, total-votes: u0 } 
        (get-dispute-counts contract-id)))
    )
    (asserts! (get disputed contract-data) err-invalid-status)
    (asserts! (is-eq (get status contract-data) "disputed") err-invalid-status)
    (asserts! (or (is-eq vote-for "client") (is-eq vote-for "freelancer")) err-invalid-status)
    (asserts! (is-none (get-dispute-vote contract-id tx-sender)) err-already-exists)
    
    (map-set dispute-votes
      { contract-id: contract-id, voter: tx-sender }
      { vote: vote-for }
    )
    
    (let
      (
        (new-client-votes (if (is-eq vote-for "client") 
          (+ (get client-votes current-counts) u1)
          (get client-votes current-counts)))
        (new-freelancer-votes (if (is-eq vote-for "freelancer")
          (+ (get freelancer-votes current-counts) u1)
          (get freelancer-votes current-counts)))
        (new-total-votes (+ (get total-votes current-counts) u1))
      )
      (map-set dispute-counts
        { contract-id: contract-id }
        { 
          client-votes: new-client-votes,
          freelancer-votes: new-freelancer-votes,
          total-votes: new-total-votes
        }
      )
      (ok true)
    )
  )
)

(define-public (resolve-dispute (contract-id uint))
  (let
    (
      (contract-data (unwrap! (get-contract contract-id) err-not-found))
      (counts (unwrap! (get-dispute-counts contract-id) err-not-found))
      (fund-data (unwrap! (get-contract-funds contract-id) err-not-found))
    )
    (asserts! (get disputed contract-data) err-invalid-status)
    (asserts! (>= (get total-votes counts) u3) err-invalid-status)
    
    (if (> (get client-votes counts) (get freelancer-votes counts))
      (begin
        (try! (as-contract (stx-transfer? (get amount fund-data) tx-sender (get client contract-data))))
        (map-set contracts
          { contract-id: contract-id }
          (merge contract-data { 
            status: "cancelled",
            completed-at: (some stacks-block-height)
          })
        )
      )
      (begin
        (try! (as-contract (stx-transfer? (get amount fund-data) tx-sender (get freelancer contract-data))))
        (map-set contracts
          { contract-id: contract-id }
          (merge contract-data { 
            status: "completed",
            completed-at: (some stacks-block-height)
          })
        )
      )
    )
    
    (map-delete contract-funds { contract-id: contract-id })
    (ok true)
  )
)

(define-public (cancel-expired-contract (contract-id uint))
  (let
    (
      (contract-data (unwrap! (get-contract contract-id) err-not-found))
      (fund-data (unwrap! (get-contract-funds contract-id) err-not-found))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get client contract-data)) err-unauthorized)
    (asserts! (is-eq (get status contract-data) "active") err-invalid-status)
    (asserts! (>= current-block (get deadline contract-data)) err-not-expired)
    (asserts! (not (get disputed contract-data)) err-invalid-status)
    
    (try! (as-contract (stx-transfer? (get amount fund-data) tx-sender (get client contract-data))))
    
    (map-set contracts
      { contract-id: contract-id }
      (merge contract-data { 
        status: "expired",
        completed-at: (some current-block)
      })
    )
    
    (map-delete contract-funds { contract-id: contract-id })
    (ok true)
  )
)

(define-public (emergency-withdraw (contract-id uint))
  (let
    (
      (contract-data (unwrap! (get-contract contract-id) err-not-found))
      (fund-data (unwrap! (get-contract-funds contract-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (try! (as-contract (stx-transfer? (get amount fund-data) tx-sender contract-owner)))
    
    (map-set contracts
      { contract-id: contract-id }
      (merge contract-data { 
        status: "emergency-withdrawn",
        completed-at: (some stacks-block-height)
      })
    )
    
    (map-delete contract-funds { contract-id: contract-id })
    (ok true)
  )
)
