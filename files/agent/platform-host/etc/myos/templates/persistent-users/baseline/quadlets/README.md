# Baseline Quadlets

Place `.container`, `.pod`, `.kube`, `.service`, `.socket`, `.timer`, or
`.target` files here when you want myOS to install them for every enrolled user.

Keep these templates per-user:

- prefer `%h`, `%u`, `%U`, `%t`, and similar specifiers
- avoid fixed shared host ports unless you parameterize them safely
- use a system unit instead if the service should run only once per machine
