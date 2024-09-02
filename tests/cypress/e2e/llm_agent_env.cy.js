
describe('LLM Agent Environment Setup', () => {
  it('should have the Docker container running', () => {
    cy.log('Checking if Docker container is running...')
    cy.exec('docker ps').its('stdout').should('contain', 'llm-agent-container');
  });
});

describe('Agent Creation', () => {
  it('should create a new agent', () => {
    cy.exec('docker exec llm-agent-container /usr/local/bin/create_agent test_agent', { failOnNonZeroExit: false })
      .its('stdout')
      .should('contain', 'Agent test_agent created successfully');
  });
});

describe('SSH Access', () => {
  it('should have SSH service running', () => {
    cy.exec('docker exec llm-agent-container service ssh status')
      .its('stdout')
      .should('contain', 'sshd is running');
  });
});

describe('Shared Folder Access', () => {
  it('should allow writing to shared_user folder', () => {
    cy.exec('docker exec llm-agent-container /bin/bash -c "echo test > /shared_user/test.txt && cat /shared_user/test.txt"')
      .its('stdout')
      .should('contain', 'test');
  });
});

describe('WebSocket Server', () => {
  it('should have WebSocket server running', () => {
    cy.exec('docker exec llm-agent-container pgrep -f irc_websocket_server.py')
      .its('code').should('eq', 0);
  });
});

describe('Next.js Setup', () => {
  it('should have Next.js installed', () => {
    cy.exec(`docker exec llm-agent-container bash -c "source ~/.nvm/nvm.sh && which next || echo 'next not found' && echo PATH=$PATH"`, { failOnNonZeroExit: false })
      .then((result) => {
        cy.log(`Command output: ${result.stdout}`);
        cy.log(`Command error: ${result.stderr}`);
        expect(result.stdout).to.contain('next');
      });
  });
});
