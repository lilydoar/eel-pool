# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Read the @README.md file to understand project context and setup instructions

## Communication Guidelines

- When completing a task, write a short final response instead of a long final response unless asked for a report or something similar.

## Behavior Guidelines

- Do not jump to conclusions when working through chains of analysis.
- Anywhere you could be missing context, or not seeing the larger picture, stop and ask clarifying questions. Questions such as information about details, decisions, or where to look to find the information you require

## Naming Conventions

The word `size` is used to denote the size in bytes. The word `length` is used to denote the count of objects.

The allocation procedures use the following conventions:

- If the name contains alloc_bytes or resize_bytes, then the procedure takes in slice parameters and returns slices.
- If the procedure name contains alloc or resize, then the procedure takes in a raw pointer and returns raw pointers.
- If the procedure name contains free_bytes, then the procedure takes in a slice.
- If the procedure name contains free, then the procedure takes in a pointer.

Higher-level allocation procedures follow the following naming scheme:

- new: Allocates a single object
- free: Free a single object (opposite of new)
- make: Allocate a group of objects
- delete: Free a group of objects (opposite of make)
