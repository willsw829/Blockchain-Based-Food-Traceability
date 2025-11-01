(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-stage (err u103))
(define-constant err-already-exists (err u104))

(define-constant err-alert-exists (err u105))
(define-constant err-alert-not-found (err u106))
(define-constant err-alert-resolved (err u107))

(define-constant seconds-per-day u144)
(define-constant days-warning-threshold u3)

(define-data-var next-alert-id uint u1)

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

(define-data-var next-batch-id uint u1)

(define-map batches
  { batch-id: uint }
  {
    name: (string-ascii 100),
    created-by: principal,
    created-at: uint,
    current-stage: (string-ascii 50),
    product-count: uint,
    is-active: bool,
  }
)

(define-map batch-products
  {
    batch-id: uint,
    product-id: uint,
  }
  { included: bool }
)

(define-private (check-product-exists (product-id uint))
  (is-some (map-get? products { product-id: product-id }))
)

(define-private (add-products-to-batch-fold (product-id uint) (batch-id uint))
  (begin
    (map-set batch-products { batch-id: batch-id, product-id: product-id } { included: true })
    batch-id
  )
)

(define-public (create-batch
    (name (string-ascii 100))
    (product-ids (list 20 uint))
  )
  (let (
      (batch-id (var-get next-batch-id))
      (valid-products (filter check-product-exists product-ids))
    )
    (asserts! (> (len valid-products) u0) err-not-found)
    (map-set batches { batch-id: batch-id } {
      name: name,
      created-by: tx-sender,
      created-at: stacks-block-height,
      current-stage: "batch-created",
      product-count: (len valid-products),
      is-active: true,
    })
    (fold add-products-to-batch-fold valid-products batch-id)
    (var-set next-batch-id (+ batch-id u1))
    (ok batch-id)
  )
)

(define-public (update-batch-stage
    (batch-id uint)
    (new-stage (string-ascii 50))
    (location (string-ascii 100))
    (notes (string-ascii 200))
  )
  (let ((batch (unwrap! (map-get? batches { batch-id: batch-id }) err-not-found)))
    (asserts! (get is-active batch) err-invalid-stage)
    (asserts! (is-eq tx-sender (get created-by batch)) err-unauthorized)
    (map-set batches { batch-id: batch-id }
      (merge batch { current-stage: new-stage })
    )
    (ok true)
  )
)

(define-read-only (get-batch (batch-id uint))
  (map-get? batches { batch-id: batch-id })
)

(define-read-only (is-product-in-batch (batch-id uint) (product-id uint))
  (default-to false
    (get included
      (map-get? batch-products { batch-id: batch-id, product-id: product-id })
    )
  )
)

(define-read-only (get-current-batch-id)
  (var-get next-batch-id)
)

(define-map quality-alerts
  { alert-id: uint }
  {
    product-id: (optional uint),
    batch-id: (optional uint),
    alert-type: (string-ascii 50),
    severity: uint,
    description: (string-ascii 300),
    issued-by: principal,
    issued-at: uint,
    is-resolved: bool,
    resolved-at: (optional uint),
    resolved-by: (optional principal),
    affected-stages: (string-ascii 200),
  }
)

(define-map product-alerts
  { product-id: uint }
  { active-alerts: uint }
)

(define-map batch-alerts
  { batch-id: uint }
  { active-alerts: uint }
)

(define-public (issue-quality-alert
    (product-id (optional uint))
    (batch-id (optional uint))
    (alert-type (string-ascii 50))
    (severity uint)
    (description (string-ascii 300))
    (affected-stages (string-ascii 200))
  )
  (let (
      (alert-id (var-get next-alert-id))
      (handler-auth (map-get? authorized-handlers { handler: tx-sender }))
    )
    (asserts!
      (or
        (is-eq tx-sender contract-owner)
        (and
          (is-some handler-auth)
          (get authorized (unwrap-panic handler-auth))
        )
      )
      err-unauthorized
    )
    (asserts! (and (>= severity u1) (<= severity u5)) err-invalid-stage)
    (asserts! (or (is-some product-id) (is-some batch-id)) err-not-found)
    
    (map-set quality-alerts { alert-id: alert-id } {
      product-id: product-id,
      batch-id: batch-id,
      alert-type: alert-type,
      severity: severity,
      description: description,
      issued-by: tx-sender,
      issued-at: stacks-block-height,
      is-resolved: false,
      resolved-at: none,
      resolved-by: none,
      affected-stages: affected-stages,
    })
    
    (match product-id
      pid (let ((current-alerts (default-to { active-alerts: u0 }
                                  (map-get? product-alerts { product-id: pid }))))
             (map-set product-alerts { product-id: pid }
               { active-alerts: (+ (get active-alerts current-alerts) u1) }))
      true)
    
    (match batch-id
      bid (let ((current-alerts (default-to { active-alerts: u0 }
                                  (map-get? batch-alerts { batch-id: bid }))))
             (map-set batch-alerts { batch-id: bid }
               { active-alerts: (+ (get active-alerts current-alerts) u1) }))
      true)
    
    (var-set next-alert-id (+ alert-id u1))
    (ok alert-id)
  )
)

(define-public (resolve-quality-alert (alert-id uint))
  (let ((alert (unwrap! (map-get? quality-alerts { alert-id: alert-id }) err-alert-not-found)))
    (asserts! (not (get is-resolved alert)) err-alert-resolved)
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set quality-alerts { alert-id: alert-id }
      (merge alert {
        is-resolved: true,
        resolved-at: (some stacks-block-height),
        resolved-by: (some tx-sender),
      }))
    (ok true)
  )
)

(define-read-only (get-quality-alert (alert-id uint))
  (map-get? quality-alerts { alert-id: alert-id })
)

(define-read-only (get-product-alert-count (product-id uint))
  (default-to u0 (get active-alerts (map-get? product-alerts { product-id: product-id })))
)

(define-read-only (get-batch-alert-count (batch-id uint))
  (default-to u0 (get active-alerts (map-get? batch-alerts { batch-id: batch-id })))
)

(define-read-only (has-active-alerts (product-id uint))
  (> (get-product-alert-count product-id) u0)
)


(define-data-var next-recall-id uint u1)

(define-map product-recalls
  { recall-id: uint }
  {
    product-id: (optional uint),
    batch-id: (optional uint),
    recall-reason: (string-ascii 300),
    severity-level: uint,
    initiated-by: principal,
    initiated-at: uint,
    affected-quantity: uint,
    recovered-quantity: uint,
    is-completed: bool,
    completion-date: (optional uint),
    regulatory-body: (string-ascii 100),
  }
)

(define-map recall-status
  {
    recall-id: uint,
    responder: principal,
  }
  {
    units-recovered: uint,
    response-timestamp: uint,
    response-notes: (string-ascii 200),
  }
)

(define-public (initiate-recall
    (product-id (optional uint))
    (batch-id (optional uint))
    (recall-reason (string-ascii 300))
    (severity-level uint)
    (affected-quantity uint)
    (regulatory-body (string-ascii 100))
  )
  (let (
      (recall-id (var-get next-recall-id))
      (handler-auth (map-get? authorized-handlers { handler: tx-sender }))
    )
    (asserts!
      (or
        (is-eq tx-sender contract-owner)
        (and
          (is-some handler-auth)
          (get authorized (unwrap-panic handler-auth))
        )
      )
      err-unauthorized
    )
    (asserts! (and (>= severity-level u1) (<= severity-level u5)) err-invalid-stage)
    (asserts! (or (is-some product-id) (is-some batch-id)) err-not-found)
    (map-set product-recalls { recall-id: recall-id } {
      product-id: product-id,
      batch-id: batch-id,
      recall-reason: recall-reason,
      severity-level: severity-level,
      initiated-by: tx-sender,
      initiated-at: stacks-block-height,
      affected-quantity: affected-quantity,
      recovered-quantity: u0,
      is-completed: false,
      completion-date: none,
      regulatory-body: regulatory-body,
    })
    (var-set next-recall-id (+ recall-id u1))
    (ok recall-id)
  )
)

(define-public (update-recall-recovery
    (recall-id uint)
    (units-recovered uint)
    (response-notes (string-ascii 200))
  )
  (let ((recall (unwrap! (map-get? product-recalls { recall-id: recall-id }) err-not-found)))
    (asserts! (not (get is-completed recall)) err-alert-resolved)
    (map-set recall-status {
      recall-id: recall-id,
      responder: tx-sender,
    } {
      units-recovered: units-recovered,
      response-timestamp: stacks-block-height,
      response-notes: response-notes,
    })
    (map-set product-recalls { recall-id: recall-id }
      (merge recall {
        recovered-quantity: (+ (get recovered-quantity recall) units-recovered)
      })
    )
    (ok true)
  )
)

(define-public (complete-recall (recall-id uint))
  (let ((recall (unwrap! (map-get? product-recalls { recall-id: recall-id }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get is-completed recall)) err-alert-resolved)
    (map-set product-recalls { recall-id: recall-id }
      (merge recall {
        is-completed: true,
        completion-date: (some stacks-block-height),
      })
    )
    (ok true)
  )
)

(define-read-only (get-recall (recall-id uint))
  (map-get? product-recalls { recall-id: recall-id })
)

(define-read-only (get-recall-response (recall-id uint) (responder principal))
  (map-get? recall-status { recall-id: recall-id, responder: responder })
)

(define-read-only (get-recall-completion-rate (recall-id uint))
  (match (map-get? product-recalls { recall-id: recall-id })
    recall (if (> (get affected-quantity recall) u0)
      (some (/ (* (get recovered-quantity recall) u100) (get affected-quantity recall)))
      none
    )
    none
  )
)

(define-map product-expiration
  { product-id: uint }
  {
    production-date: uint,
    expiration-date: uint,
    shelf-life-days: uint,
    set-by: principal,
    last-updated: uint,
    extension-count: uint,
  }
)

(define-public (set-product-expiration
    (product-id uint)
    (shelf-life-days uint)
  )
  (let (
      (product (unwrap! (map-get? products { product-id: product-id }) err-not-found))
      (handler-auth (map-get? authorized-handlers { handler: tx-sender }))
      (production-date stacks-block-height)
      (expiration-date (+ production-date (* shelf-life-days seconds-per-day)))
    )
    (asserts!
      (or
        (is-eq tx-sender (get producer product))
        (and
          (is-some handler-auth)
          (get authorized (unwrap-panic handler-auth))
        )
      )
      err-unauthorized
    )
    (ok (map-set product-expiration { product-id: product-id } {
      production-date: production-date,
      expiration-date: expiration-date,
      shelf-life-days: shelf-life-days,
      set-by: tx-sender,
      last-updated: stacks-block-height,
      extension-count: u0,
    }))
  )
)

(define-public (extend-shelf-life
    (product-id uint)
    (additional-days uint)
  )
  (let ((expiration-data (unwrap! (map-get? product-expiration { product-id: product-id }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= additional-days u7) err-invalid-stage)
    (ok (map-set product-expiration { product-id: product-id }
      (merge expiration-data {
        expiration-date: (+ (get expiration-date expiration-data) (* additional-days seconds-per-day)),
        extension-count: (+ (get extension-count expiration-data) u1),
        last-updated: stacks-block-height,
      })
    ))
  )
)

(define-read-only (get-expiration-info (product-id uint))
  (map-get? product-expiration { product-id: product-id })
)

(define-read-only (is-product-expired (product-id uint))
  (match (map-get? product-expiration { product-id: product-id })
    expiration-data (>= stacks-block-height (get expiration-date expiration-data))
    false
  )
)

(define-read-only (is-near-expiration (product-id uint))
  (match (map-get? product-expiration { product-id: product-id })
    expiration-data (let ((blocks-until-expiry (- (get expiration-date expiration-data) stacks-block-height)))
      (and
        (< stacks-block-height (get expiration-date expiration-data))
        (<= blocks-until-expiry (* days-warning-threshold seconds-per-day))
      )
    )
    false
  )
)

(define-read-only (get-freshness-status (product-id uint))
  (if (is-product-expired product-id)
    "expired"
    (if (is-near-expiration product-id)
      "near-expiration"
      "fresh"
    )
  )
)