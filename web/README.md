# README.md

# Project Sloth MDT

## Overview

Project Sloth MDT is a FiveM resource designed to facilitate the management of police reports and related data. It provides a structured way to handle incidents, warrants, and other law enforcement-related information through a secure and efficient database interface.

## Features

- Fetch and manage police reports
- Handle vehicle plate scans with BOLO and warrant checks
- Integration with `oxmysql` for secure SQL operations
- Easy-to-use ORM for database interactions

## Setup Instructions

1. **Clone the repository**:

    ```bash
    git clone https://github.com/yourusername/ps-mdt-v3.git
    ```

2. **Install dependencies**:
   Ensure you have the required dependencies installed, including `oxmysql`.

3. **Configure the database**:
   Update the database connection settings in your `fxmanifest.lua` or any configuration file as needed.

4. **Start the resource**:
   Add `start ps-mdt-v3` to your server configuration file (e.g., `server.cfg`).

## Usage Guidelines

- Use the provided server events to interact with the MDT system.
- Ensure that only authorized personnel can access sensitive data.
- Follow best practices for database management and security.

## Contributing

Contributions are welcome! Please submit a pull request or open an issue for any enhancements or bug fixes.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.
