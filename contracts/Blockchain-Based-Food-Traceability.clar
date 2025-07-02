(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-stage (err u103))
(define-constant err-already-exists (err u104))

(define-data-var next-product-id uint u1)

(define-map products
  { product-id: uint }
  {
    name: (string-ascii 100),
    origin: (string-ascii 100),
    producer: principal,
    created-at: uint,
    current-stage: (string-ascii 50),
    is-organic: bool,
    is-fair-trade: bool,
    current-owner: principal,
  }
)

(define-map product-history
  {
    product-id: uint,
    stage-id: uint,
  }
  {
    stage: (string-ascii 50),
    location: (string-ascii 100),
    timestamp: uint,
    handler: principal,
    temperature: (optional int),
    notes: (string-ascii 200),
  }
)

(define-map product-stage-count
  { product-id: uint }
  { count: uint }
)

(define-map authorized-handlers
  { handler: principal }
  {
    authorized: bool,
    role: (string-ascii 50),
  }
)

(define-map producer-certifications
  { producer: principal }
  {
    organic-certified: bool,
    fair-trade-certified: bool,
    certification-date: uint,
    certifying-body: (string-ascii 100),
  }
)

(define-public (authorize-handler
    (handler principal)
    (role (string-ascii 50))
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set authorized-handlers { handler: handler } {
      authorized: true,
      role: role,
    }))
  )
)

(define-public (revoke-handler (handler principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set authorized-handlers { handler: handler } {
      authorized: false,
      role: "",
    }))
  )
)

(define-public (add-producer-certification
    (producer principal)
    (organic bool)
    (fair-trade bool)
    (certifying-body (string-ascii 100))
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set producer-certifications { producer: producer } {
      organic-certified: organic,
      fair-trade-certified: fair-trade,
      certification-date: stacks-block-height,
      certifying-body: certifying-body,
    }))
  )
)

(define-public (create-product
    (name (string-ascii 100))
    (origin (string-ascii 100))
    (is-organic bool)
    (is-fair-trade bool)
  )
  (let (
      (product-id (var-get next-product-id))
      (producer-cert (map-get? producer-certifications { producer: tx-sender }))
    )
    (asserts!
      (or
        (not is-organic)
        (and
          (is-some producer-cert)
          (get organic-certified (unwrap-panic producer-cert))
        )
      )
      err-unauthorized
    )
    (asserts!
      (or
        (not is-fair-trade)
        (and
          (is-some producer-cert)
          (get fair-trade-certified (unwrap-panic producer-cert))
        )
      )
      err-unauthorized
    )
    (map-set products { product-id: product-id } {
      name: name,
      origin: origin,
      producer: tx-sender,
      created-at: stacks-block-height,
      current-stage: "farm",
      is-organic: is-organic,
      is-fair-trade: is-fair-trade,
      current-owner: tx-sender,
    })
    (map-set product-stage-count { product-id: product-id } { count: u1 })
    (map-set product-history {
      product-id: product-id,
      stage-id: u1,
    } {
      stage: "farm",
      location: origin,
      timestamp: stacks-block-height,
      handler: tx-sender,
      temperature: none,
      notes: "Product created at farm",
    })
    (var-set next-product-id (+ product-id u1))
    (ok product-id)
  )
)

(define-public (update-product-stage
    (product-id uint)
    (new-stage (string-ascii 50))
    (location (string-ascii 100))
    (temperature (optional int))
    (notes (string-ascii 200))
  )
  (let (
      (product (unwrap! (map-get? products { product-id: product-id }) err-not-found))
      (handler-auth (map-get? authorized-handlers { handler: tx-sender }))
      (stage-count-data (unwrap! (map-get? product-stage-count { product-id: product-id })
        err-not-found
      ))
      (current-count (get count stage-count-data))
      (new-count (+ current-count u1))
    )
    (asserts!
      (or
        (is-eq tx-sender (get current-owner product))
        (and
          (is-some handler-auth)
          (get authorized (unwrap-panic handler-auth))
        )
      )
      err-unauthorized
    )
    (map-set products { product-id: product-id }
      (merge product {
        current-stage: new-stage,
        current-owner: tx-sender,
      })
    )
    (map-set product-stage-count { product-id: product-id } { count: new-count })
    (map-set product-history {
      product-id: product-id,
      stage-id: new-count,
    } {
      stage: new-stage,
      location: location,
      timestamp: stacks-block-height,
      handler: tx-sender,
      temperature: temperature,
      notes: notes,
    })
    (ok new-count)
  )
)

(define-public (transfer-ownership
    (product-id uint)
    (new-owner principal)
  )
  (let ((product (unwrap! (map-get? products { product-id: product-id }) err-not-found)))
    (asserts! (is-eq tx-sender (get current-owner product)) err-unauthorized)
    (ok (map-set products { product-id: product-id }
      (merge product { current-owner: new-owner })
    ))
  )
)

(define-read-only (get-product (product-id uint))
  (map-get? products { product-id: product-id })
)

(define-read-only (get-product-history
    (product-id uint)
    (stage-id uint)
  )
  (map-get? product-history {
    product-id: product-id,
    stage-id: stage-id,
  })
)

(define-read-only (get-product-stage-count (product-id uint))
  (map-get? product-stage-count { product-id: product-id })
)

(define-read-only (get-handler-authorization (handler principal))
  (map-get? authorized-handlers { handler: handler })
)

(define-read-only (get-producer-certification (producer principal))
  (map-get? producer-certifications { producer: producer })
)

(define-read-only (get-full-product-trace (product-id uint))
  (let (
      (product (map-get? products { product-id: product-id }))
      (stage-count-data (map-get? product-stage-count { product-id: product-id }))
    )
    (if (and (is-some product) (is-some stage-count-data))
      (some {
        product: (unwrap-panic product),
        total-stages: (get count (unwrap-panic stage-count-data)),
      })
      none
    )
  )
)

(define-read-only (verify-organic-claim (product-id uint))
  (match (map-get? products { product-id: product-id })
    product (let ((producer-cert (map-get? producer-certifications { producer: (get producer product) })))
      (and
        (get is-organic product)
        (is-some producer-cert)
        (get organic-certified (unwrap-panic producer-cert))
      )
    )
    false
  )
)

(define-read-only (verify-fair-trade-claim (product-id uint))
  (match (map-get? products { product-id: product-id })
    product (let ((producer-cert (map-get? producer-certifications { producer: (get producer product) })))
      (and
        (get is-fair-trade product)
        (is-some producer-cert)
        (get fair-trade-certified (unwrap-panic producer-cert))
      )
    )
    false
  )
)

(define-read-only (get-current-product-id)
  (var-get next-product-id)
)

(define-map product-ratings
  {
    product-id: uint,
    rating-id: uint,
  }
  {
    rating: uint,
    review: (string-ascii 200),
    reviewer: principal,
    stage: (string-ascii 50),
    timestamp: uint,
  }
)

(define-map product-rating-count
  { product-id: uint }
  { count: uint }
)

(define-map product-rating-totals
  { product-id: uint }
  { total: uint }
)

(define-public (rate-product
    (product-id uint)
    (rating uint)
    (review (string-ascii 200))
  )
  (let (
      (product (unwrap! (map-get? products { product-id: product-id }) err-not-found))
      (rating-count-data (default-to { count: u0 } (map-get? product-rating-count { product-id: product-id })))
      (rating-total-data (default-to { total: u0 } (map-get? product-rating-totals { product-id: product-id })))
      (current-count (get count rating-count-data))
      (current-total (get total rating-total-data))
      (new-count (+ current-count u1))
      (new-total (+ current-total rating))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-stage)
    (map-set product-ratings {
      product-id: product-id,
      rating-id: new-count,
    } {
      rating: rating,
      review: review,
      reviewer: tx-sender,
      stage: (get current-stage product),
      timestamp: stacks-block-height,
    })
    (map-set product-rating-count { product-id: product-id } { count: new-count })
    (map-set product-rating-totals { product-id: product-id } { total: new-total })
    (ok new-count)
  )
)

(define-read-only (get-product-rating (product-id uint) (rating-id uint))
  (map-get? product-ratings { product-id: product-id, rating-id: rating-id })
)

(define-read-only (get-average-rating (product-id uint))
  (let (
      (count-data (map-get? product-rating-count { product-id: product-id }))
      (total-data (map-get? product-rating-totals { product-id: product-id }))
    )
    (if (and (is-some count-data) (is-some total-data))
      (let (
          (count (get count (unwrap-panic count-data)))
          (total (get total (unwrap-panic total-data)))
        )
        (if (> count u0)
          (some (/ total count))
          none
        )
      )
      none
    )
  )
)