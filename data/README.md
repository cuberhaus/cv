# Career inventory

`career.yaml` is the public, English-first factual source used to propose
role-specific CV content. It supplements the hand-maintained LaTeX sections; it
does not generate, overwrite, or publish a CV.

## Authoring contract

Run `make validate-career` after every edit. The validator enforces non-empty
required fields, `YYYY-MM` dates, HTTPS evidence links, and globally unique
stable IDs, including nested achievement IDs.

IDs use lowercase kebab-case and must remain stable when wording changes. Create
a new ID only for a genuinely new fact. Dates use `YYYY-MM`; only an experience
`end_date` may use `present`.

The top-level fields are:

- `schema_version`: currently `1`.
- `person`: identity, location, and language proficiency.
- `experience`: employment or consulting engagements.
- `education`: qualifications and institutions.
- `projects`: significant professional, academic, or personal projects.
- `skills`: grouped technologies and capabilities.
- `certifications`: externally issued credentials.

Every collection record has an `id` and `tags`. Records other than skills also
have:

- `publishable`: whether the fact may be proposed for public CV content.
- `evidence`: zero or more public HTTPS sources supporting the fact.

An empty `evidence` list means no public source is currently recorded; it does
not authorize an AI to infer or embellish the entry. Do not put private
documents, credentials, personal contact details, or confidential client
information in this public inventory.

### Collection fields

- Experience records use `organization`, `role`, `location`, `start_date`,
  `end_date`, and `achievements`. Each achievement has its own stable `id`,
  factual `text`, and a `metrics` mapping. Keep unknown metrics absent rather
  than estimating them.
- Education records use `institution`, `qualification`, `location`,
  `start_date`, and `end_date`.
- Project records use `name` and `summary`; `context` may identify an academic,
  competition, or employment setting.
- Skill records use `category` and `items`. Add only skills supported by the
  surrounding career record or other reviewable evidence.
- Certification records use `name` and `issued_at`.

Preserve granular achievements and alternate facts here. Concise final wording
belongs in a reviewed CV proposal, not in destructive edits to this inventory.

## Reviewed tailoring workflow

1. Update `career.yaml` with any newly verified facts.
2. Run `make validate-career` and commit the inventory separately from generated
   proposals when practical.
3. Give an AI the job description and this inventory, using the prompt below.
4. Review every selected fact, translation, and proposed metric.
5. Manually update all affected English, Spanish, and Catalan LaTeX section
   files, then build the relevant Docker-backed CV variants.

Example prompt:

```text
Using the supplied job description and data/career.yaml, propose a CV content
selection for this role.

Constraints:
- Use only facts present in career.yaml.
- Exclude records where publishable is false.
- Do not invent metrics, dates, employers, technologies, or evidence.
- Cite each proposed bullet with its source record ID and achievement ID.
- Explain briefly why each fact is relevant to the job description.
- Flag missing evidence or ambiguous facts instead of resolving them yourself.
- Return a reviewable proposal only; do not edit or generate LaTeX.
- Draft in English unless I explicitly request Spanish or Catalan.

Job description:
<paste the complete job description here>
```

AI output is advisory. A human must approve it before any LaTeX content changes
or generated PDF is published.
