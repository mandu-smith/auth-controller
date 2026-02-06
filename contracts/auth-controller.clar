;; title: auth-controller
;; version:
;; summary:
;; description:
;; Green Energy Trading Platform Contract
;; Handles trading of green energy credits, verification of production, and participant management

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INVALID-ENERGY-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-ENERGY-BALANCE (err u102))
(define-constant ERR-ENERGY-PRODUCER-NOT-FOUND (err u103))
(define-constant ERR-ENERGY-CONSUMER-NOT-FOUND (err u104))
(define-constant ERR-PARTICIPANT-ALREADY-REGISTERED (err u105))
(define-constant ERR-INVALID-TRADE-STATUS (err u106))
(define-constant ERR-INVALID-ENERGY-PRICE (err u107))
(define-constant ERR-INVALID-PRODUCER-ADDRESS (err u108))

;; Data Maps
(define-map energy-producers
  principal
  {
    cumulative-energy-produced: uint,
    producer-verification-status: bool,
    producer-registration-timestamp: uint,
    energy-unit-price: uint,
  }
)

(define-map energy-consumers
  principal
  {
    cumulative-energy-purchased: uint,
    available-energy-credits: uint,
    consumer-registration-timestamp: uint,
  }
)

(define-map energy-trading-records
  uint
  {
    energy-seller: principal,
    energy-buyer: principal,
    energy-amount: uint,
    transaction-price: uint,
    transaction-timestamp: uint,
    trade-status: (string-ascii 20),
  }
)

;; Variables
(define-data-var energy-trade-sequence uint u0)
(define-data-var platform-administrator principal tx-sender)
(define-data-var minimum-tradeable-energy uint u100)
(define-data-var platform-commission-rate uint u2)
(define-data-var maximum-energy-price uint u1000000) ;; Set a reasonable maximum price

;; Read-only functions
(define-read-only (get-energy-producer-details (producer-address principal))
  (map-get? energy-producers producer-address)
)

(define-read-only (get-energy-consumer-details (consumer-address principal))
  (map-get? energy-consumers consumer-address)
)

(define-read-only (get-energy-trade-details (trade-identifier uint))
  (map-get? energy-trading-records trade-identifier)
)

(define-read-only (get-platform-commission-rate)
  (var-get platform-commission-rate)
)

;; Private functions
(define-private (calculate-platform-commission (energy-amount uint))
  (/ (* energy-amount (var-get platform-commission-rate)) u100)
)

(define-private (transfer-energy-credit-balance
    (seller-address principal)
    (buyer-address principal)
    (transfer-amount uint)
  )
  (let (
      (seller-details (unwrap! (map-get? energy-producers seller-address)
        ERR-ENERGY-PRODUCER-NOT-FOUND
      ))
      (buyer-details (unwrap! (map-get? energy-consumers buyer-address)
        ERR-ENERGY-CONSUMER-NOT-FOUND
      ))
    )
    (if (>= (get cumulative-energy-produced seller-details) transfer-amount)
      (begin
        (map-set energy-producers seller-address
          (merge seller-details { cumulative-energy-produced: (- (get cumulative-energy-produced seller-details) transfer-amount) })
        )
        (map-set energy-consumers buyer-address
          (merge buyer-details { available-energy-credits: (+ (get available-energy-credits buyer-details) transfer-amount) })
        )
        (ok true)
      )
      ERR-INSUFFICIENT-ENERGY-BALANCE
    )
  )
)