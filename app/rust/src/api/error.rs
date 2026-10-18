/// Erros expostos ao Dart. Sem mensagens: nada de segredo ou conteúdo vaza
/// por texto de erro.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CoreError {
    /// Palavras com contagem errada ou fora da lista.
    InvalidInvite,
    /// Pedido de entrada que não abre com a chave de admissão (sem o convite).
    WrongInvite,
    /// Mensagem MLS malformada, adulterada, repetida ou fora da época.
    InvalidMessage,
    /// Texto acima de 1000 caracteres.
    TooLong,
    /// Operação fora de hora (ex.: cifrar antes de entrar no grupo).
    NotReady,
    /// Falha interna da biblioteca.
    Internal,
}

impl std::fmt::Display for CoreError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for CoreError {}
