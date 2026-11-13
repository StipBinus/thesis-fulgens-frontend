class ApiConfig {
  //run ipconfig trus ganti pake IPv4 Address kalian, misal (192.168.1.8) 8080 backend, 8081 keycloak,

  // static const String backendUrl = 'http://10.239.155.192:8080';
  // static const String keycloakUrl = 'http://10.239.155.192:8081';

  static const String backendUrl = 'http://localhost:8080';
  static const String keycloakUrl = 'http://localhost:8081';

  getBackendUrl() {
    return backendUrl;
  }

  getKeycloakUrl() {
    return keycloakUrl;
  }
}
