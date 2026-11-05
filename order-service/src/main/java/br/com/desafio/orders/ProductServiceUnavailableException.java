package br.com.desafio.orders;

public class ProductServiceUnavailableException extends RuntimeException {

    public ProductServiceUnavailableException(Throwable cause) {
        super("Não foi possível consultar o catálogo de produtos.", cause);
    }
}
