# Morpho Blue

Morpho Blue is a new lending primitive that offers better rates, high capital efficiency and extended flexibility to lenders & borrowers.

## Whitepaper

The protocol is described in detail in the [Morpho Blue Whitepaper](./morpho-blue-whitepaper.pdf).

## Repository Structure

[`Morpho.sol`](./src/Morpho.sol) contains most of the source code of the core contract of Morpho Blue.
It solely relies on internal libraries in the [`src/libraries`](./src/libraries) subdirectory.

Libaries in the [`src/libraries/periphery`](./src/libraries/periphery) directory are not used by Morpho Blue.
They are useful helpers that integrators can reuse or adapt to their own needs.

The [src/mocks](./src/mocks) directory contains contracts designed exclusively for testing.

You'll find relevant comments in [Morpho's interface](./src/interfaces/IMorpho.sol), notably a list of assumptions about market dependencies.

## Getting Started

Install dependencies: `yarn`

Run forge tests: `yarn test:forge`

Run hardhat tests: `yarn test:hardhat`

You will find other useful commands in the [`package.json`](./package.json) file.

## Audits

All audits are stored in the [audits](./audits/)' folder.

## Licensing

The primary license for Morpho Blue is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE).
However, some files are dual licensed under `GPL-2.0-or-later`.

All files in the following folders can also be licensed under `GPL-2.0-or-later` (as indicated in their SPDX headers):
- `src/interfaces`, see [`src/interfaces/LICENSE`](./src/interfaces/LICENSE)
- `src/libraries`, see [`src/libraries/LICENSE`](./src/libraries/LICENSE)
- `src/mocks`, see [`src/mocks/LICENSE`](./src/mocks/LICENSE)
- `test`, see [`test/LICENSE`](./test/LICENSE)
