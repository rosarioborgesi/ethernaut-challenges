# 🛡️ Ethernaut Solutions

This repository contains my solutions to the **OpenZeppelin Ethernaut challenges**.

🔗 https://ethernaut.openzeppelin.com/

Ethernaut is a wargame that teaches **smart contract security** through hands-on challenges.

---

## 🎯 What this repo shows

This repository demonstrates:

- 🔍 vulnerability analysis  
- 🧠 structured exploitation reasoning  
- 🛠️ practical solutions using **Foundry**  
- 🧪 reproducible attacks (scripts + tests)

Each challenge is solved end-to-end with a clear and consistent approach.

---

## ⚙️ Setup

- **Tooling:** Foundry  
- **Network:** Ethereum Sepolia  

---

## 📂 Repository Structure

Each challenge has its own folder with a complete breakdown of the solution.

### Structure

```

ethernaut-solutions
│
├── challenge-00-hello-ethernaut
│   ├── README.md
│   ├── Challenge.sol
│   ├── Attacker.sol
│   └── ...
│
├── challenge-01-fallback
│   └── ...
│
└── ...

```

---

## 🧠 What each challenge includes

For every challenge:

- 📄 **README.md**
  - goal of the challenge  
  - vulnerability explanation  
  - reasoning behind the exploit  
  - commands used (Foundry / cast)

- 🧾 **Challenge code**
  - original contract from Ethernaut  

- 🛠️ **Solution code**
  - attacker contracts or scripts  

---

## 🧪 Tests (when included)

Some challenges also include **Foundry tests** in the `/test` folder.

These tests:

- reproduce the exploit locally  
- validate the attack logic  
- simulate real attack scenarios  

---

## 📬 Addresses

**My wallet**
```
0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0
```

**Ethernaut main contract**
```
0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6
```

---

## 🧩 Solved Challenges

| #  | Challenge              | Instance Address                           |
|----|------------------------|--------------------------------------------|
| 00 | Hello Ethernaut        | 0x42d884C1247939966a96A082155320f752CB6fd0 |
| 01 | Fallback               | 0x7362C5A8A4449Fedd2103ca8CFa641CBf061a23E |
| 02 | Fallout                | 0xE53a2EBA4218FAE1f4DB2c3abE62A7daB4E28dA7 |
| 03 | Coin Flip              | 0x1a5484deA83d16f70AF980D04B40CC6568676aE7 |
| 04 | Telephone              | 0x4b0e263C8E936DEf791EbAf420EaeF8F8c0A574B |
| 05 | Token                  | 0xB4ceb3270C4cE2De83DA503235ad214FD4D75357 |
| 06 | Delegation             | 0x9294C53875B19eD1F91ecac4AE16b5895046cF1c |
| 07 | Force                  | 0x3Aa4E20aED5d03E82E58b68b89fF73F86d60016b |
| 08 | Vault                  | 0xe018a3454E7572ea50018f9F4813335987e231FA |
| 09 | King                   | 0x6A2CA55902D70aA546C04b8bfE0ac3212f95D64a |
| 10 | Re-entrancy            | 0x4F688a59A5Ca69dD306D7445b619316545DA7d79 |
| 11 | Elevator               | 0xFee3bd70D1313ef9ea54EDdfC9cbDcA3ce5cf003 |
| 12 | Privacy                | 0x7fFBF1444f2D487FF9b3240a774700352aA772e8 |
| 13 | Gatekeeper One         | 0x2A8613f30D946baf392870bC93a0570808bA25a3 |
| 14 | Gatekeeper Two         | 0x2AE2F44a2896f194bCe2c5a0A1883e53C1F9FB6e |
| 15 | Naught Coin            | 0xde793CbdCc4B70eE335b29638e066A4705a565df |
| 16 | Preservation           | 0x97e653C5A8CDF2ED240724974F6462199a87AB0B |
| 17 | Recovery               | 0x748eB39299eB709498ebB87a996bd9432F2E2D11 |
| 18 | Magic Number           | 0x804197e08B99b7953cC146DAdED199a7210F491b |
| 19 | Alien Codex            | 0x18D6E71d6902673445DC30c1271c7e56007E9026 |
| 20 | Denial                 | 0x7605C41F2a34616F699F363DEB97adF28cAdF343 |
| 21 | Shop                   | 0xC96C9Bd099b74DB1E7b98e8d0A422D067f3ADE28 |
| 22 | Dex                    | 0x69222B1ac7950bEc5fc46cB377D7B92c2834fb7f |
| 23 | Dex Two                | 0x51Bc355E1c0093b61933508246Ea4ec01a9De71F |
| 24 | Puzzle Wallet          | 0x8573cA54260a177c618A3B028fD02E0D904307cB |
| 25 | Motorbike              | 0x30649a58B74d44A3EDD7c21e29749Cf76542d078 |
| 26 | DoubleEntryPoint       | 0x2f83dCa66ffDbF6b8615FC87BdE31797e2Dd3d39 |
| 27 | Good Samaritan         | 0x8B307734D65ceB74A52B350BC13b0cA8B7859246 |
| 28 | Gatekeeper Three       | 0xA39c7757e03071E95d132537dd74559E3E05b8E8 |
| 29 | Switch                 |                                            |
| 30 | Higher Order           | 0x628EeF867757540991899d3155baE509313d3683 |
| 31 | Stake                  | 0x0Ae53C54BFDDA8B9c53EEd01A514c98B4a5A1de1 |
| 32 | Impersonator           | 0x18a54Da1BFb716a01Aba43d5C00c03a02c7AF8d9 |
| 33 | Magic Animal Carousel  | 0x3e52E6932aa2F68ea0BBe21D44B9DD9Cb40b4D72 |
| 34 | Bet House              | 0xbbEA21974e1132F7Ff0C10Df5b64f1A1E327AC49 |

---

## 🔗 Ethernaut Profile

https://ethernaut.openzeppelin.com/level/0x3c34A342b2aF5e885FcaA3800dB5B205fEfa3ffB

---

## 👤 Author

**Rosario Borgesi**

Solidity developer focused on **smart contract development and security**

---

## 🌐 Connect with Me
<p align="left">
  <a href="https://x.com/rosarioborgesi">
    <img src="https://img.shields.io/badge/twitter-000000?style=for-the-badge&logo=x&logoColor=white"/>
  </a>
  <a href="https://www.linkedin.com/in/rosarioborgesi/">
    <img src="https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white"/>
  </a>
  <a href="mailto:borgesiros@gmail.com">
    <img src="https://img.shields.io/badge/Email-D14836?style=for-the-badge&logo=gmail&logoColor=white"/>
  </a>
  <a href="https://www.youtube.com/@rosarioborgesi">
    <img src="https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white"/>
  </a>
  <a href="https://farcaster.xyz/rosarioborgesi">
    <img src="https://img.shields.io/badge/Farcaster-855DCD?style=for-the-badge"/>
  </a>
  <a href="https://medium.com/@rosarioborgesi/">
    <img src="https://img.shields.io/badge/Medium-000000?style=for-the-badge&logo=medium&logoColor=white"/>
  </a>
</p>

