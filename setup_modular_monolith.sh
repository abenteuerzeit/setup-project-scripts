#!/bin/bash

################################################################################
# Script Name: setup_modular_monolith.sh                                        #
# Description: This script sets up a basic modular monolith project structure. #
# It creates a directory structure, initializes Git, creates necessary files,  #
# installs dependencies, and generates a tsconfig.json for TypeScript config.  #
#                                                                              #
# Usage:                                                                       #
# ./setup_modular_monolith.sh <project-name>                                   #
#                                                                              #
# Example:                                                                     #
# ./setup_modular_monolith.sh my-project                                       #
################################################################################

# Ensure the script exits on any command failure
set -e

# Trap any errors, logging the line where they occur
trap 'echo "Error occurred on line $LINENO" | tee -a setup.log; exit 1' ERR

# Check for required command-line tools: git and node
# Exit if any of the tools are not installed
for cmd in git node; do
  command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd is required but it's not installed. Aborting." | tee -a setup.log; exit 1; }
done

# Define the project name and required modules
PROJECT_NAME=${1:-"modular-monolith"}
MODULES=("authentication" "backend" "database" "deployment" "frontend")

# Start the project setup process and log it
echo "Setting up modular monolith for project: $PROJECT_NAME" | tee -a setup.log

# Create modular directory structure
for MODULE in "${MODULES[@]}"; do
  DIR="${PROJECT_NAME}/src/modules/${MODULE}"
  if [[ ! -d $DIR ]]; then
    mkdir -p $DIR
    echo "Created directory: $DIR" | tee -a setup.log
  else
    echo "Directory already exists: $DIR" | tee -a setup.log
  fi
done

# Create additional directories for shared utilities, tests, scripts, and assets
DIRECTORIES=($PROJECT_NAME/src/shared/{utilities,types} $PROJECT_NAME/tests $PROJECT_NAME/scripts $PROJECT_NAME/assets/{images,styles})
for DIR in "${DIRECTORIES[@]}"; do
  if [[ ! -d $DIR ]]; then
    mkdir -p $DIR
    echo "Created directory: $DIR" | tee -a setup.log
  else
    echo "Directory already exists: $DIR" | tee -a setup.log
  fi
done

# Navigate to the newly created project directory
cd $PROJECT_NAME

# Initialize a new Git repository for the project
git init | tee -a setup.log

# Create essential files for the project (e.g., Dockerfile, README, scripts, etc.)
FILES=(src/index.ts Dockerfile kubernetes-config.yaml package.json README.md scripts/{db_init.sql,tables_init.sql} .gitignore)
for FILE in "${FILES[@]}"; do
  if [[ ! -f $FILE ]]; then
    touch $FILE
    echo "Created file: $FILE" | tee -a setup.log
  else
    echo "File already exists: $FILE" | tee -a setup.log
  fi
done

# Initialize a Node.js project with default settings
npm init -y | tee -a setup.log
if [ $? -ne 0 ]; then
    echo "Error initializing Node.js project." | tee -a setup.log
    exit 1
fi

# Install essential npm packages for the project
npm install express react react-dom redux typescript pg | tee -a setup.log
if [ $? -ne 0 ]; then
    echo "Error installing dependencies." | tee -a setup.log
    exit 1
fi

# Initialize TypeScript configuration
npx tsc --init | tee -a setup.log
if [ $? -ne 0 ]; then
    echo "Error setting up TypeScript." | tee -a setup.log
    exit 1
fi

# Output TypeScript configuration
cat > tsconfig.json << EOF
{
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "module": "commonjs",
    "esModuleInterop": true
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

# Setup Express.js
cat > src/modules/backend/index.ts << EOF
import express from 'express';
const app = express();
app.listen(3000, () => console.log('Server is running on port 3000'));
EOF

# Setup React
npx create-react-app src/modules/frontend --template typescript --use-npm | tee -a setup.log

# Create .env and sample.env files
cat > .env << EOF
DB_CONNECTION_STRING=postgresql://username:password@hostname:port/database_name
EOF

cat > sample.env << EOF
DB_CONNECTION_STRING=postgresql://username:password@hostname:port/database_name
EOF

# Create Dockerfile
cat > Dockerfile << EOF
FROM node:18.13.0
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci
COPY . .
EXPOSE 3000
CMD [ "node", "dist/modules/backend/index.js" ]
EOF

# Create Kubernetes deployment config
cat > kubernetes-config.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $PROJECT_NAME-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: $PROJECT_NAME
  template:
    metadata:
      labels:
        app: $PROJECT_NAME
    spec:
      containers:
      - name: $PROJECT_NAME
        image: $PROJECT_NAME:latest
        ports:
        - containerPort: 3000
EOF

# Create a README file with setup instructions
cat > README.md << EOF
# $PROJECT_NAME

## Setup

1. Clone the repository: \`git clone <repository-url>\`
2. Change directory: \`cd $PROJECT_NAME\`
3. Install dependencies: \`npm install\`
4. Copy \`sample.env\` to \`.env\` and update with your database credentials.
5. Start the backend: \`node src/modules/backend/index.ts\`
6. Start the frontend: \`cd src/modules/frontend && npm start\`
EOF

# Create an initial commit
git add . | tee -a setup.log

# Check if there are changes to be committed
if git diff-index --quiet HEAD --; then
    echo "No changes to commit." | tee -a setup.log
else
    git commit -m "Initial project setup" | tee -a setup.log
fi

# Create and switch to a development branch
git checkout -b development | tee -a setup.log

# Output post-setup checklist
echo "
Project setup complete. Switched to development branch.
...
" | tee -a setup.log

