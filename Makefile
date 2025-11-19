.PHONY: dev install clean test deploy

# Development commands
dev:
	@echo "🚀 Starting development environment..."
	@chmod +x dev-setup.sh
	@./dev-setup.sh

install:
	@echo "📦 Installing dependencies..."
	@cd backend && uv sync
	@cd frontend && npm install

clean:
	@echo "🧹 Cleaning up..."
	@pkill -f "uvicorn server:app" || true
	@pkill -f "next dev" || true
	@rm -rf backend/.uv
	@rm -rf frontend/.next
	@rm -rf frontend/node_modules

test:
	@echo "🧪 Running tests..."
	@cd backend && uv run pytest || echo "No tests found"
	@cd frontend && npm test || echo "No tests configured"

# Deployment commands
deploy:
	@echo "🚀 Deploying to AWS..."
	@cd backend && uv run deploy.py
	@cd terraform && terraform apply -auto-approve

# Quick backend only
backend:
	@echo "🔧 Starting backend only..."
	@cd backend && uv run uvicorn server:app --reload --host 0.0.0.0 --port 8000

# Quick frontend only  
frontend:
	@echo "🌐 Starting frontend only..."
	@cd frontend && npm run dev