---
# API Glossary

This glossary defines the enums, objects, and special fields used in the SeqCode Registry API.

---

## Enums

### `status_name`
The status of a name in the registry. Possible values:

- **`public`**: Publicly available.
- **`automated`**: Automatically generated.
- **`SeqCode`**: Valid under the SeqCode.
- **`ICNP`**: Valid under the International Code of Nomenclature of Prokaryotes.
- **`ICNafp`**: Valid under the International Code of Nomenclature for algae, fungi, and plants.
- **`valid`**: Valid under any code.

---

### `kind` (for genomes)
The kind of genome. Possible values:

- **`isolate`**: Genome from a single isolate.
- **`enrichment`**: Enriched community genome.
- **`mag`**: Metagenome-assembled genome.
- **`sag`**: Single-cell amplified genome.
- **`null`**: Unknown or not applicable.

---

### `rank`
The taxonomic rank of a name. Possible values:

- **`domain`**
- **`kingdom`**
- **`phylum`**
- **`class`**
- **`order`**
- **`family`**
- **`genus`**
- **`species`**
- **`subspecies`**

---

## Special Fields

### `nomenclatural_type` (Object)
The nomenclatural type associated with a name. This is a **hash (object)** with the following structure:

| Key       | Type   | Description                                                                                     | Example Value                     |
|-----------|--------|-------------------------------------------------------------------------------------------------|-----------------------------------|
| `class`   | string | The **type** of the nomenclatural type. Possible values: `Name`, `Genome`, `Strain`, `Other`, `unknown`. | `"Name"`, `"Genome"`, `"Other"`, `"unknown"` |
| `id`      | int    | The unique identifier of the nomenclatural type (if applicable).                                | `26160`                          |
| `url`     | string | The URL to the nomenclatural type resource (if applicable).                                    | `"https://api.seqco.de/v1/names/26160.json"` |
| `uri`     | string | The URI of the nomenclatural type (if applicable).                                             | `"https://seqco.de/i:26160"`     |
| `display` | string | A human-readable display name for the nomenclatural type (if applicable).                     | `"Desulfogranum mediterraneum"` |

##### Possible Values for `class`:
- **`"Name"`**: The nomenclatural type is another **Name** (e.g., a type species for a genus).
- **`"Genome"`**: The nomenclatural type is a **Genome** (e.g., a type genome for a species).
- **`"Strain"`**: The nomenclatural type is a **Strain** (e.g., a type strain for a species).
- **`"Other"`**: The nomenclatural type is a **GenericTypeMaterial** (e.g., any other type of material).
- **`"unknown"`**: The nomenclatural type is **not defined** or **unknown**.