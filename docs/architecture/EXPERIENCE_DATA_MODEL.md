# Experience Data Model

## Overview

DataSchema defines structured persistence for Experiences that need local data.

## Structure

- Entities (tables/collections)
- Fields (columns/properties)
- Types (integer, string, boolean, decimal, date, list, map)
- Required/optional constraints
- Default values
- Schema version

## Operations

Controlled operations only:
- insert
- read
- query
- update
- delete
- count
- sort
- filter

No arbitrary SQL from generated packages.

## Local-First

All data storage is local. No remote database required for initial Experiences.
