# Assignment 4, Cloud App Dev

## Exercise 1: Application Security Best Practices on Google Cloud

**Objective:** Implement security best practices in a Google Cloud application.

### Tasks:

#### Set Up a Google Cloud Project:
- Create a new Google Cloud project.
- Enable necessary APIs (e.g., Cloud Storage, Cloud SQL, Compute Engine).

#### Identity and Access Management (IAM):
- Create a service account for your application and assign the principle of least privilege.
- Implement IAM conditions to restrict access based on attributes.

#### Data Protection:
- Set up encryption for data at rest using Google Cloud KMS.
- Use HTTPS for data in transit and configure load balancers to enforce SSL.

#### Application Security Testing:
- Integrate a security scanning tool (e.g., Snyk, OWASP ZAP) into your CI/CD pipeline.
- Conduct a vulnerability assessment of your application and document findings.

#### Monitoring and Logging:
- Enable Google Cloud Audit Logs for your project.
- Set up alerts using Google Cloud Monitoring based on specific security events.

#### Incident Response:
- Create an incident response plan detailing steps to take in case of a security breach.
- Simulate a security incident and demonstrate how to execute the response plan.

---

## Exercise 2: Scaling Applications on Google Cloud

**Objective:** Design and implement a scalable application using Google Cloud services.

### Tasks:

#### Application Design:
- Create a simple web application (e.g., a to-do list or blog).
- Use Cloud Functions for serverless computing or Google Kubernetes Engine (GKE) for containerized applications.

#### Horizontal vs. Vertical Scaling:
- Document scenarios where horizontal scaling (adding more instances) is preferred over vertical scaling (upgrading instance types).
- Implement both scaling methods in your application and benchmark performance.

#### Load Balancing:
- Set up Google Cloud Load Balancing to distribute traffic across multiple instances.
- Configure health checks to ensure traffic is routed only to healthy instances.

#### Auto-Scaling:
- Implement auto-scaling for Compute Engine or GKE based on CPU usage and request load.
- Create policies that define scaling behavior under different conditions.

#### Monitoring Performance:
- Use Google Cloud Monitoring to track application performance metrics.
- Set up dashboards to visualize resource usage and application health.

#### Cost Optimization:
- Analyze your application’s performance and suggest optimizations to reduce costs while maintaining scalability.
- Implement recommendations and track cost savings.
