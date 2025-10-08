# 🌱 Blockchain-Based Food Traceability

A comprehensive smart contract system for tracking food products from farm to table, ensuring transparency, reducing food fraud, and verifying organic and fair-trade claims on the Stacks blockchain.

## 🚀 Features

- 📦 **Product Creation**: Farmers can register new food products with origin details
- 🔄 **Supply Chain Tracking**: Track products through multiple stages (farm → processing → distribution → retail)
- 🏷️ **Certification Management**: Verify organic and fair-trade certifications
- 👥 **Role-Based Access**: Authorize handlers at different supply chain stages
- 📊 **Complete Traceability**: Full history tracking with timestamps and locations
- 🌡️ **Environmental Data**: Optional temperature and condition monitoring
- ✅ **Fraud Prevention**: Cryptographic verification of claims and ownership

## 🛠️ Contract Functions

### Public Functions

#### Product Management
- `create-product(name, origin, is-organic, is-fair-trade)` - Create a new food product
- `update-product-stage(product-id, new-stage, location, temperature, notes)` - Move product to next stage
- `transfer-ownership(product-id, new-owner)` - Transfer product ownership

#### Authorization & Certification
- `authorize-handler(handler, role)` - Authorize supply chain handlers (owner only)
- `revoke-handler(handler)` - Revoke handler authorization (owner only)
- `add-producer-certification(producer, organic, fair-trade, certifying-body)` - Add producer certifications (owner only)

### Read-Only Functions

#### Product Information
- `get-product(product-id)` - Get basic product information
- `get-product-history(product-id, stage-id)` - Get specific stage history
- `get-full-product-trace(product-id)` - Get complete product trace summary

#### Verification
- `verify-organic-claim(product-id)` - Verify organic certification claims
- `verify-fair-trade-claim(product-id)` - Verify fair-trade certification claims
- `get-producer-certification(producer)` - Get producer certification details

#### System Info
- `get-handler-authorization(handler)` - Check handler authorization status
- `get-current-product-id()` - Get next available product ID

## 📋 Usage Examples

### 1. Setting Up Producers

```clarity
;; Contract owner adds organic certification for a farmer
(contract-call? .food-traceability add-producer-certification 
  'SP1FARMER123 
  true    ;; organic certified
  false   ;; not fair-trade certified
  "USDA Organic")
```

### 2. Creating Products

```clarity
;; Farmer creates an organic tomato product
(contract-call? .food-traceability create-product 
  "Organic Tomatoes" 
  "Green Valley Farm, CA" 
  true   ;; is organic
  false) ;; not fair-trade
```

### 3. Authorizing Supply Chain Handlers

```clarity
;; Authorize a processing facility
(contract-call? .food-traceability authorize-handler 
  'SP1PROCESSOR123 
  "processor")

;; Authorize a distributor
(contract-call? .food-traceability authorize-handler 
  'SP1DISTRIBUTOR123 
  "distributor")
```

### 4. Tracking Through Supply Chain

```clarity
;; Move product from farm to processing
(contract-call? .food-traceability update-product-stage 
  u1                           ;; product-id
  "processing"                 ;; new stage
  "Fresh Foods Processing, CA" ;; location
  (some 4)                    ;; temperature (4°C)
  "Washed and packaged")      ;; notes

;; Move to distribution
(contract-call? .food-traceability update-product-stage 
  u1 
  "distribution" 
  "FreshCorp Distribution Center, NV" 
  (some 2) 
  "In cold storage")
```

### 5. Verifying Product Claims

```clarity
;; Verify organic claim
(contract-call? .food-traceability verify-organic-claim u1)
;; Returns: true (if properly certified)

;; Get complete product information
(contract-call? .food-traceability get-full-product-trace u1)
```

## 🔧 Development Setup

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
clarinet new food-traceability-project
cd food-traceability-project
```

Copy the contract code to `contracts/Blockchain-Based-Food-Traceability.clar`

### Testing

```bash
clarinet console
```

### Deployment

```bash
clarinet deploy --testnet
```

## 🏗️ Supply Chain Stages

Common stages in the food traceability system:

1. **🚜 Farm** - Initial product creation
2. **🏭 Processing** - Food processing and packaging
3. **🚚 Distribution** - Wholesale distribution
4. **🏪 Retail** - Retail stores and markets
5. **🍽️ Consumer** - Final consumer purchase

## 🔐 Security Features

- **Role-based access control** - Only authorized handlers can update stages
- **Certification verification** - Organic/fair-trade claims must be backed by valid certifications
- **Immutable history** - All supply chain events are permanently recorded
- **Ownership tracking** - Clear chain of custody throughout supply chain

## 🌍 Use Cases

- **Organic Food Verification** - Consumers can verify organic claims
- **Food Safety Recalls** - Quickly trace contaminated products to source
- **Fair Trade Compliance** - Verify ethical sourcing claims
- **Supply Chain Optimization** - Analyze bottlenecks and inefficiencies
- **Regulatory Compliance** - Meet food safety and labeling requirements

## 📄 License

MIT License - Feel free to use and modify for your food traceability needs!

## 🤝 Contributing

Contributions welcome! Please feel free to submit pull requests or open issues for improvements.
```

**Git Commit Message:**
```
feat: implement blockchain food traceability MVP with certification verification
```

**GitHub Pull Request Title:**
```
🌱 Add Blockchain-Based Food Traceability Smart Contract MVP
