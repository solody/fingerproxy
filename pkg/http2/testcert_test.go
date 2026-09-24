package http2_test

import (
	"crypto/tls"

	"github.com/wi1dcard/fingerproxy/pkg/http2/internal/testcert"
)

var (
	testTLSServerConfig = &tls.Config{
		InsecureSkipVerify: true,
		Certificates:       []tls.Certificate{testCert},
	}
	testTLSClientConfig = &tls.Config{
		InsecureSkipVerify: true,
	}
)

var testCert = func() tls.Certificate {
	cert, err := tls.X509KeyPair(testcert.LocalhostCert, testcert.LocalhostKey)
	if err != nil {
		panic(err)
	}
	return cert
}()
