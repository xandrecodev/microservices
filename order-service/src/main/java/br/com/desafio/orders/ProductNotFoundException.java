package br.com.desafio.orders;

public class ProductNotFoundException extends RuntimeException {

    public ProductNotFoundException(Long productId) {
        super("Produto não encontrado: " + productId);
    }
}
