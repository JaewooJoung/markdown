Question 1: Write a Julia function to implement a basic transformer decoder block for private LLM model development. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 트랜스포머 디코더 블록 구현
# 주요 컴포넌트: Multi-head Self Attention, Cross Attention, Feed Forward Network

using Flux

struct TransformerDecoderBlock
    # 셀프 어텐션 레이어
    self_attention::MultiHeadAttention
    # 크로스 어텐션 레이어 
    cross_attention::MultiHeadAttention
    # 피드포워드 네트워크
    feed_forward::Chain
    # 레이어 정규화
    norm1::LayerNorm
    norm2::LayerNorm
    norm3::LayerNorm
    # 드롭아웃
    dropout::Dropout
end

"""
트랜스포머 디코더 블록 생성자
params:
    - d_model: 모델의 차원 수
    - n_heads: 어텐션 헤드의 수
    - d_ff: 피드포워드 네트워크의 은닉층 차원
    - dropout_prob: 드롭아웃 확률
"""
function TransformerDecoderBlock(d_model::Int, n_heads::Int, d_ff::Int, dropout_prob::Float32)
    # 멀티헤드 어텐션 초기화
    self_attention = MultiHeadAttention(d_model, n_heads)
    cross_attention = MultiHeadAttention(d_model, n_heads)
    
    # 피드포워드 네트워크 정의
    feed_forward = Chain(
        Dense(d_model, d_ff, gelu),
        Dense(d_ff, d_model)
    )
    
    # 레이어 정규화 초기화
    norm1 = LayerNorm(d_model)
    norm2 = LayerNorm(d_model)
    norm3 = LayerNorm(d_model)
    
    # 드롭아웃 레이어
    dropout = Dropout(dropout_prob)
    
    return TransformerDecoderBlock(
        self_attention, cross_attention, feed_forward,
        norm1, norm2, norm3, dropout
    )
end

"""
디코더 블록의 순전파
params:
    - x: 입력 텐서
    - enc_output: 인코더의 출력
    - mask: 디코더 마스크
    - enc_mask: 인코더-디코더 마스크
"""
function (block::TransformerDecoderBlock)(x, enc_output, mask=nothing, enc_mask=nothing)
    # 셀프 어텐션 수행
    # 첫 번째 Add & Norm
    attn1 = block.self_attention(x, x, x, mask)
    attn1 = block.dropout(attn1)
    out1 = block.norm1(x + attn1)
    
    # 크로스 어텐션 수행
    # 두 번째 Add & Norm
    attn2 = block.cross_attention(out1, enc_output, enc_output, enc_mask)
    attn2 = block.dropout(attn2)
    out2 = block.norm2(out1 + attn2)
    
    # 피드포워드 네트워크 통과
    # 세 번째 Add & Norm
    ff = block.feed_forward(out2)
    ff = block.dropout(ff)
    out3 = block.norm3(out2 + ff)
    
    return out3
end

# 멀티헤드 어텐션 구현 
struct MultiHeadAttention
    # 쿼리, 키, 밸류 변환을 위한 가중치
    W_q::Dense
    W_k::Dense
    W_v::Dense
    # 출력 프
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 2: Write a Julia function to load and serve an on-premise LLM model with security constraints. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function to load and serve an on-premise LLM with security constraints, with Korean comments:

```julia
using Flux
using JSON
using HTTP
using JWT
using SHA

# 보안 설정을 위한 구조체
struct SecurityConfig
    api_key::String
    max_tokens::Int
    allowed_ips::Vector{String}
    rate_limit::Int  # 분당 요청 제한
end

# LLM 모델 및 보안 설정을 관리하는 구조체
mutable struct LLMService
    model::Any
    security::SecurityConfig
    request_count::Dict{String, Tuple{Int, Float64}}  # IP별 요청 카운트 및 타임스탬프
end

"""
    요청의 유효성을 검사하는 함수
"""
function validate_request(service::LLMService, headers::HTTP.Headers, ip::String)::Bool
    # API 키 확인
    if !haskey(headers, "Authorization") || headers["Authorization"] != "Bearer $(service.security.api_key)"
        return false
    end

    # IP 주소 확인
    if !(ip in service.security.allowed_ips)
        return false
    end

    # 속도 제한 확인
    current_time = time()
    if haskey(service.request_count, ip)
        count, last_time = service.request_count[ip]
        if current_time - last_time <= 60.0  # 1분 이내
            if count >= service.security.rate_limit
                return false
            end
            service.request_count[ip] = (count + 1, last_time)
        else
            service.request_count[ip] = (1, current_time)
        end
    else
        service.request_count[ip] = (1, current_time)
    end

    return true
end

"""
    LLM 모델을 로드하고 서비스를 시작하는 함수
"""
function load_and_serve_llm(model_path::String, port::Int=8080)
    # 모델 로드
    println("모델을 로드하는 중...")
    model = load_model(model_path)  # 실제 모델 로딩 함수로 교체 필요

    # 보안 설정 초기화
    security_config = SecurityConfig(
        generate_api_key(),  # 랜덤 API 키 생성
        1000,  # 최대 토큰 수
        ["127.0.0.1"],  # 허용된 IP 주소
        60  # 분당 최대 요청 수
    )

    # 서비스 인스턴스 생성
    service = LLMService(model, security_config, Dict{String, Tuple{Int, Float64}}())

    # HTTP 서버 설정
    router = HTTP.Router()

    # 추론 엔드포인트
    HTTP.register!(router, "POST", "/generate", function(req)
        # 클라이언트 IP 주소 추출
        client_ip = HTTP.Headers["X-Forwarded-For"]

        # 요청 유효성 검사
        if !validate_request(service, req.headers, client_ip)
            return HTTP.Response(401, "Unauthorized")
        end

        # 요청 본문 파싱
        body = JSON.parse(String(req.body))

        try
            # 모델 추론 실행
            input_text = body["input"]
            response = generate_text(service.model, input_text)

            # 응답 반환
            return HTTP.Response(200, JSON.json(Dict(
                "generated_text" => response,
                "status" => "success"
            )))
        catch e
            return HTTP.Response(500, JSON.json(Dict(
                "error" => string(e),
                "status" =>
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 3: Write a Julia function to implement RAG (Retrieval-Augmented Generation) document retrieval system. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 Julia로 구현한 RAG (Retrieval-Augmented Generation) 문서 검색 시스템입니다:

```julia
using LinearAlgebra
using JSON
using SentenceTokenizers
using Word2Vec

"""
문서 검색을 위한 RAG 시스템 구조체
- documents: 문서 컬렉션
- embeddings: 문서의 임베딩 벡터
- tokenizer: 문장 토크나이저
- model: Word2Vec 모델
"""
struct RAGSystem
    documents::Vector{String}
    embeddings::Matrix{Float64}
    tokenizer::SentenceTokenizer
    model::Word2VecModel
end

"""
텍스트를 벡터로 변환하는 함수
- text: 입력 텍스트
- model: Word2Vec 모델
반환값: 텍스트의 평균 임베딩 벡터
"""
function text_to_vector(text::String, model::Word2VecModel)
    # 텍스트를 토큰화
    tokens = split(lowercase(text))
    
    # 각 단어의 임베딩을 가져와서 평균 계산
    vectors = []
    for token in tokens
        try
            push!(vectors, get_vector(model, token))
        catch
            continue
        end
    end
    
    # 임베딩이 없는 경우 처리
    if isempty(vectors)
        return zeros(Float64, get_vector_size(model))
    end
    
    return mean(vectors)
end

"""
RAG 시스템 초기화 함수
- documents: 문서 컬렉션
- model_path: Word2Vec 모델 경로
반환값: RAGSystem 인스턴스
"""
function initialize_rag(documents::Vector{String}, model_path::String)
    # Word2Vec 모델 로드
    model = word2vec_load_model(model_path)
    
    # 문장 토크나이저 초기화
    tokenizer = SentenceTokenizer()
    
    # 문서 임베딩 계산
    embeddings = zeros(Float64, length(documents), get_vector_size(model))
    for (i, doc) in enumerate(documents)
        embeddings[i, :] = text_to_vector(doc, model)
    end
    
    return RAGSystem(documents, embeddings, tokenizer, model)
end

"""
유사도 기반 문서 검색 함수
- rag: RAG 시스템
- query: 검색 쿼리
- k: 반환할 상위 문서 수
반환값: (문서 인덱스, 유사도 점수) 튜플의 벡터
"""
function retrieve_documents(rag::RAGSystem, query::String, k::Int=3)
    # 쿼리 벡터 생성
    query_vector = text_to_vector(query, rag.model)
    
    # 코사인 유사도 계산
    similarities = [dot(query_vector, rag.embeddings[i, :]) / 
                   (norm(query_vector) * norm(rag.embeddings[i, :]))
                   for i in 1:size(rag.embeddings, 1)]
    
    # 상위 k개 문서 선택
    sorted_indices = sortperm(similarities, rev=true)[1:min(k, length(similarities))]
    
    return [(i, similarities[i]) for i in sorted_indices]
end

"""
사용 예시:
"""
function example_usage()
    # 샘플 문서
    documents = [
        "인공지능은 컴퓨터 과학의 한 분야입니다.",
        "머신러닝은 데이터로
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 4: Write a Julia function to create MCP (Model Context Protocol) message handlers for LLM applications. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 LLM 애플리케이션을 위한 MCP(Model Context Protocol) 메시지 핸들러를 생성하는 Julia 함수입니다:

```julia
# MCP 메시지 타입 정의
struct MCPMessage
    role::String
    content::String
    metadata::Dict{String, Any}
end

"""
MCP 컨텍스트를 관리하기 위한 타입
history: 대화 이력을 저장
max_tokens: 최대 토큰 수
temperature: 생성 텍스트의 무작위성 정도
"""
mutable struct MCPContext
    history::Vector{MCPMessage}
    max_tokens::Int
    temperature::Float64
end

"""
새로운 MCP 컨텍스트를 초기화하는 함수
"""
function create_mcp_context(max_tokens::Int=2048, temperature::Float64=0.7)
    MCPContext(MCPMessage[], max_tokens, temperature)
end

"""
메시지를 MCP 컨텍스트에 추가하는 함수
context: MCP 컨텍스트
role: 메시지 작성자의 역할 (system, user, assistant)
content: 메시지 내용
metadata: 추가 메타데이터
"""
function add_message!(context::MCPContext, role::String, content::String, metadata::Dict{String, Any}=Dict{String, Any}())
    push!(context.history, MCPMessage(role, content, metadata))
end

"""
MCP 컨텍스트에서 프롬프트를 생성하는 함수
context: MCP 컨텍스트
"""
function generate_prompt(context::MCPContext)::String
    prompt = ""
    for message in context.history
        prompt *= "$(message.role): $(message.content)\n"
    end
    return prompt
end

"""
MCP 컨텍스트를 처리하는 핸들러 함수
context: MCP 컨텍스트
llm_function: LLM API 호출 함수
"""
function handle_mcp!(context::MCPContext, llm_function::Function)
    # 프롬프트 생성
    prompt = generate_prompt(context)
    
    # LLM 호출을 위한 파라미터 설정
    params = Dict(
        "prompt" => prompt,
        "max_tokens" => context.max_tokens,
        "temperature" => context.temperature
    )
    
    try
        # LLM 함수 호출
        response = llm_function(params)
        
        # 응답을 컨텍스트에 추가
        add_message!(context, "assistant", response)
        
        return response
    catch e
        println("오류 발생: ", e)
        return nothing
    end
end

"""
사용 예시를 보여주는 함수
"""
function example_usage()
    # 더미 LLM 함수
    dummy_llm(params) = "이것은 LLM의 응답입니다."
    
    # 컨텍스트 생성
    context = create_mcp_context()
    
    # 시스템 메시지 추가
    add_message!(context, "system", "당신은 도움이 되는 AI 어시스턴트입니다.")
    
    # 사용자 메시지 추가
    add_message!(context, "user", "안녕하세요!")
    
    # 메시지 처리
    response = handle_mcp!(context, dummy_llm)
    
    println("응답: ", response)
end
```

### 주요 기능 설명:

- `MCPMessage`: 각각의 메시지를 저장하는 구조체
- `
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 5: Write a Julia function to chunk documents for RAG embedding storage. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
"""
문서를 더 작은 청크로 나누는 함수입니다.
긴 문서를 임베딩하기 위해 적절한 크기의 조각들로 나눕니다.

매개변수:
- text: 청크화할 텍스트 문자열
- chunk_size: 각 청크의 목표 크기 (토큰 수)
- overlap: 청크 간 중복되는 토큰 수
- min_chunk_size: 허용되는 최소 청크 크기

반환값:
- 청크 문자열의 벡터
"""
function chunk_document(text::String; 
                       chunk_size::Int=500,
                       overlap::Int=50,
                       min_chunk_size::Int=50)
    
    # 공백을 기준으로 텍스트를 토큰으로 분리
    tokens = split(text)
    
    # 토큰 수가 chunk_size보다 작으면 전체 텍스트를 반환
    if length(tokens) <= chunk_size
        return [text]
    end
    
    chunks = String[]
    start_idx = 1
    
    # 청크 생성 루프
    while start_idx <= length(tokens)
        # 청크의 끝 인덱스 계산
        end_idx = min(start_idx + chunk_size - 1, length(tokens))
        
        # 현재 청크의 토큰들을 결합
        current_chunk = join(tokens[start_idx:end_idx], " ")
        
        # 최소 크기 이상인 경우에만 청크 추가
        if length(split(current_chunk)) >= min_chunk_size
            push!(chunks, current_chunk)
        end
        
        # 다음 청크의 시작점을 overlap을 고려하여 계산
        start_idx = start_idx + (chunk_size - overlap)
    end
    
    return chunks
end

# 청크 메타데이터를 생성하는 헬퍼 함수
"""
각 청크에 대한 메타데이터를 생성합니다.

매개변수:
- chunks: 청크 문자열의 벡터
- doc_id: 원본 문서의 식별자

반환값:
- 메타데이터 딕셔너리의 벡터
"""
function create_chunk_metadata(chunks::Vector{String}, doc_id::String)
    return [Dict(
        "doc_id" => doc_id,
        "chunk_id" => i,
        "chunk_size" => length(split(chunk)),
        "position" => i/length(chunks)
    ) for (i, chunk) in enumerate(chunks)]
end

# 사용 예시:
#=
text = "긴 문서의 내용..."
chunks = chunk_document(text, chunk_size=300, overlap=30)
metadata = create_chunk_metadata(chunks, "doc_001")

for (chunk, meta) in zip(chunks, metadata)
    println("청크 크기: $(meta["chunk_size"])")
    println("청크 내용의 일부: $(chunk[1:min(50, length(chunk))])...")
    println("---")
end
=#
```

이 코드에 대한 설명:

### 주요 기능
- `chunk_document` 함수는 긴 텍스트를 더 작은 청크로 나눕니다
- 텍스트 처리를 위한 기본적인 토큰화는 공백을 기준으로 합니다
- 청크 간 중복을 허용하여 문맥의 연속성을 유지합니다

### 매개변수 설
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 6: Write a Julia function to implement semantic search over vector embeddings. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 벡터 임베딩을 사용한 시맨틱 검색을 구현하는 함수들입니다

"""
코사인 유사도를 계산하는 함수
query_vec: 쿼리 벡터
doc_vec: 문서 벡터
반환값: 두 벡터 간의 코사인 유사도 (-1 ~ 1 사이의 값)
"""
function cosine_similarity(query_vec::Vector{Float64}, doc_vec::Vector{Float64})
    # 분자: 두 벡터의 내적
    dot_product = sum(query_vec .* doc_vec)
    
    # 분모: 두 벡터의 크기(norm)를 곱한 값
    query_norm = sqrt(sum(query_vec.^2))
    doc_norm = sqrt(sum(doc_vec.^2))
    
    # 코사인 유사도 계산
    return dot_product / (query_norm * doc_norm)
end

"""
임베딩 벡터들 중에서 쿼리 벡터와 가장 유사한 상위 k개를 찾는 함수
query_vec: 쿼리 벡터
doc_vecs: 문서 벡터들의 배열
doc_ids: 문서 ID들의 배열 
k: 반환할 상위 결과 개수
반환값: (문서 ID, 유사도 점수)로 구성된 튜플의 배열
"""
function semantic_search(query_vec::Vector{Float64}, 
                       doc_vecs::Vector{Vector{Float64}},
                       doc_ids::Vector{String}, 
                       k::Int)
    # 입력값 유효성 검사
    @assert length(doc_vecs) == length(doc_ids) "문서 벡터와 ID 개수가 일치해야 합니다"
    @assert k <= length(doc_vecs) "k는 전체 문서 수보다 작거나 같아야 합니다"
    
    # 각 문서 벡터와의 유사도 계산
    similarities = [(id, cosine_similarity(query_vec, doc_vec)) 
                   for (id, doc_vec) in zip(doc_ids, doc_vecs)]
    
    # 유사도 기준 내림차순 정렬
    sort!(similarities, by = x -> x[2], rev=true)
    
    # 상위 k개 결과 반환
    return similarities[1:k]
end

"""
사용 예시를 위한 헬퍼 함수
doc_count: 생성할 샘플 문서 수
vec_dim: 벡터의 차원
반환값: 무작위로 생성된 문서 벡터들과 ID들
"""
function generate_sample_data(doc_count::Int, vec_dim::Int)
    # 무작위 문서 벡터 생성
    doc_vecs = [rand(Float64, vec_dim) for _ in 1:doc_count]
    
    # 문서 ID 생성
    doc_ids = ["doc_$(i)" for i in 1:doc_count]
    
    return doc_vecs, doc_ids
end

# 사용 예시
function example_usage()
    # 샘플 데이터 생성 (100개 문서, 128차원 벡터)
    doc_vecs, doc_ids = generate_sample_data(100, 128)
    
    # 임의의 쿼리 벡터 생성
    query_vec = rand(Float64, 128)
    
    # 상위 5개 유사 문서 검색
    results =
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 7: Write a Julia function to build a domain-specific vocabulary for specialized LLM training. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function to build a domain-specific vocabulary with Korean comments:

```julia
# 도메인 특화 어휘 생성을 위한 모듈
module DomainVocabBuilder

using DataStructures

"""
텍스트에서 어휘를 추출하고 빈도수를 계산하는 기본 구조체
"""
struct VocabStats
    word_freq::Counter{String}    # 단어 빈도수 저장
    min_freq::Int                 # 최소 빈도 임계값
    max_vocab_size::Int           # 최대 어휘 크기
end

"""
텍스트를 전처리하는 함수
- 소문자 변환
- 특수문자 제거
- 공백 정규화
"""
function preprocess_text(text::String)
    # 소문자로 변환
    text = lowercase(text)
    # 특수문자 제거 (알파벳, 숫자, 공백만 유지)
    text = replace(text, r"[^a-z0-9\s]" => " ")
    # 연속된 공백을 하나로 통일
    text = replace(text, r"\s+" => " ")
    return strip(text)
end

"""
텍스트 코퍼스에서 도메인 특화 어휘 생성
params:
    - texts: 텍스트 문서 배열
    - min_freq: 최소 단어 빈도
    - max_vocab_size: 최대 어휘 크기
"""
function build_domain_vocabulary(
    texts::Vector{String},
    min_freq::Int=2,
    max_vocab_size::Int=50000
)
    # 빈도수 카운터 초기화
    word_counter = Counter{String}()
    
    # 각 텍스트 처리
    for text in texts
        # 텍스트 전처리
        clean_text = preprocess_text(text)
        # 단어 분리
        words = split(clean_text)
        # 단어 빈도수 계산
        for word in words
            increment!(word_counter, word)
        end
    end
    
    # 빈도수 기준으로 어휘 필터링
    filtered_vocab = filter(pair -> pair.second >= min_freq, word_counter)
    
    # 최대 어휘 크기에 맞춰 상위 단어만 선택
    sorted_vocab = sort(collect(filtered_vocab), by=x->x.second, rev=true)
    final_vocab = sorted_vocab[1:min(length(sorted_vocab), max_vocab_size)]
    
    return VocabStats(counter(Dict(final_vocab)), min_freq, max_vocab_size)
end

"""
어휘 통계 출력 함수
"""
function print_vocab_stats(vocab::VocabStats)
    println("어휘 통계:")
    println("총 단어 수: ", length(vocab.word_freq))
    println("최소 빈도 임계값: ", vocab.min_freq)
    println("최대 어휘 크기: ", vocab.max_vocab_size)
    
    # 상위 10개 단어와 빈도수 출력
    println("\n상위 10개 빈출 단어:")
    top_words = sort(collect(vocab.word_freq), by=x->x.second, rev=true)[1:min(10, length(vocab.word_freq))]
    for (word, freq) in top_words
        println("$word: $freq")
    end
end

"""
어휘를 파일로 저장하는 함수
"""
function save_vocabulary(vocab::VocabStats, filename::String)
    open(filename, "w") do file
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 8: Write a Julia function to implement attention mechanism following GPT architecture. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 GPT 스타일의 어텐션 메커니즘을 구현한 Julia 함수입니다:

```julia
using LinearAlgebra

"""
스케일드 닷-프로덕트 어텐션을 구현하는 함수
입력:
- query: 쿼리 행렬 (batch_size × head_dim × seq_len)
- key: 키 행렬 (batch_size × head_dim × seq_len)
- value: 값 행렬 (batch_size × head_dim × seq_len)
- mask: 어텐션 마스크 (선택적)
"""
function scaled_dot_product_attention(query, key, value, mask=nothing)
    # 어텐션 스코어 계산
    d_k = size(key, 2)  # 키의 차원
    scores = batched_mul(query, permutedims(key, (1, 3, 2))) ./ sqrt(d_k)
    
    # 마스크가 제공된 경우 적용
    if mask !== nothing
        scores = scores .+ mask
    end
    
    # 소프트맥스 적용
    attention_weights = softmax(scores, dims=3)
    
    # 가중치와 값을 곱하여 최종 출력 계산
    return batched_mul(attention_weights, value)
end

"""
멀티헤드 어텐션을 구현하는 함수
입력:
- X: 입력 텐서 (batch_size × seq_len × d_model)
- n_heads: 어텐션 헤드의 수
"""
function multi_head_attention(X, n_heads)
    batch_size, seq_len, d_model = size(X)
    head_dim = div(d_model, n_heads)
    
    # 선형 변환을 위한 가중치 초기화
    W_q = randn(d_model, d_model) ./ sqrt(d_model)
    W_k = randn(d_model, d_model) ./ sqrt(d_model)
    W_v = randn(d_model, d_model) ./ sqrt(d_model)
    W_o = randn(d_model, d_model) ./ sqrt(d_model)
    
    # 쿼리, 키, 값 생성
    Q = reshape(X * W_q, batch_size, n_heads, head_dim, seq_len)
    K = reshape(X * W_k, batch_size, n_heads, head_dim, seq_len)
    V = reshape(X * W_v, batch_size, n_heads, head_dim, seq_len)
    
    # 각 헤드에 대해 어텐션 계산
    heads = []
    for i in 1:n_heads
        head = scaled_dot_product_attention(
            Q[:, i, :, :],
            K[:, i, :, :],
            V[:, i, :, :]
        )
        push!(heads, head)
    end
    
    # 모든 헤드를 연결하고 출력 투영
    concat_heads = cat(heads..., dims=2)
    output = reshape(concat_heads, batch_size, seq_len, d_model) * W_o
    
    return output
end

"""
소프트맥스 함수 구현
"""
function softmax(x; dims=1)
    exp_x = exp.(x .- maximum(x, dims=dims))
    return exp_x ./ sum(exp_x, dims=dims)
end

"""
배치 행렬 곱셈을 수행하는 헬퍼 함수
"""
function batched_mul(a, b)
    return cat([a[i:i,:,:] * b[i:i,:,:
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 9: Write a Julia function to create rotary positional embeddings (RoPE) like in Llama models. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
"""
회전 위치 임베딩(RoPE, Rotary Position Embeddings)을 생성하는 함수들입니다.
RoPE는 Transformer 모델에서 토큰의 상대적 위치 정보를 인코딩하는데 사용됩니다.
"""

using LinearAlgebra

"""
θ_i를 계산하는 함수입니다.
dim: 임베딩 차원
pos: 시퀀스에서의 위치
i: 차원 인덱스
base: θ 계산에 사용되는 기본값 (기본값 10000.0)
"""
function get_theta(dim::Int, pos::Int, i::Int, base::Float32=10000.0f0)
    return pos / (base^(2i/dim))
end

"""
회전 행렬을 생성하는 함수입니다.
theta: 회전각
"""
function get_rotation_matrix(theta::Float32)
    return Float32[cos(theta) -sin(theta);
                   sin(theta) cos(theta)]
end

"""
주어진 벡터에 RoPE를 적용하는 함수입니다.
x: 입력 벡터 (head_dim 크기)
pos: 시퀀스에서의 위치
"""
function apply_rope(x::Vector{Float32}, pos::Int)
    # 입력 벡터의 차원이 짝수인지 확인
    @assert iseven(length(x)) "입력 벡터의 차원은 짝수여야 합니다"
    
    head_dim = length(x)
    result = copy(x)
    
    # 2차원씩 묶어서 회전 적용
    for i in 0:2:head_dim-2
        dim_idx = i ÷ 2
        theta = get_theta(head_dim, pos, dim_idx)
        rot_matrix = get_rotation_matrix(theta)
        
        # 2차원 부분 벡터에 회전 적용
        result[i+1:i+2] = rot_matrix * x[i+1:i+2]
    end
    
    return result
end

"""
배치된 입력에 대해 RoPE를 적용하는 함수입니다.
X: 입력 텐서 [배치, 시퀀스 길이, 임베딩 차원]
"""
function apply_rope_batch(X::Array{Float32, 3})
    batch_size, seq_len, head_dim = size(X)
    result = similar(X)
    
    for b in 1:batch_size
        for s in 1:seq_len
            result[b,s,:] = apply_rope(X[b,s,:], s-1)  # 0-based position
        end
    end
    
    return result
end

# 사용 예시:
"""
# 테스트 코드
x = rand(Float32, 8)  # 8차원 임베딩
pos = 3  # 시퀀스에서의 위치

# 단일 벡터에 RoPE 적용
result = apply_rope(x, pos)

# 배치 처리
batch = rand(Float32, 2, 5, 8)  # [배치크기=2, 시퀀스길이=5, 임베딩차원=8]
batch_result = apply_rope_batch(batch)
"""
```

이 코드에 대한 설명:

1. `get_theta`: 
   - RoPE의 회전각을 계산하는 함수입니다
   - 위치와 차원 인덱스에 따라 다른 θ값을 반환합니다
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 10: Write a Julia function to implement grouped-query attention for efficient inference. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 그룹화된 쿼리 어텐션(Grouped-Query Attention) 구현
# 메모리 효율적인 추론을 위해 쿼리를 그룹화하여 어텐션을 계산합니다.

"""
grouped_query_attention(query, key, value, num_groups, mask=nothing)

입력:
- query: 쿼리 텐서 (batch_size, seq_len, dim)
- key: 키 텐서 (batch_size, seq_len, dim) 
- value: 값 텐서 (batch_size, seq_len, dim)
- num_groups: 쿼리 그룹의 수
- mask: 어텐션 마스크 (선택적)

출력:
- 어텐션 출력 텐서 (batch_size, seq_len, dim)
"""
function grouped_query_attention(query, key, value, num_groups; mask=nothing)
    # 입력 크기 가져오기
    batch_size, seq_len, dim = size(query)
    
    # 쿼리를 그룹으로 나누기
    # 각 그룹은 seq_len/num_groups 크기를 가집니다
    group_size = div(seq_len, num_groups)
    grouped_queries = reshape(query, (batch_size, num_groups, group_size, dim))
    
    # 스케일링 팩터 계산
    scale = 1.0f0 / sqrt(Float32(dim))
    
    # 결과를 저장할 텐서 초기화
    output = zeros(Float32, batch_size, seq_len, dim)
    
    # 각 그룹별로 어텐션 계산
    for g in 1:num_groups
        # 현재 그룹의 쿼리 선택
        q = grouped_queries[:, g, :, :]
        
        # 어텐션 스코어 계산
        scores = batched_mul(q, permutedims(key, (1, 3, 2))) .* scale
        
        # 마스크 적용 (있는 경우)
        if !isnothing(mask)
            scores = scores .+ mask
        end
        
        # softmax 적용
        attention_weights = softmax(scores, dims=3)
        
        # 가중치와 값을 곱하여 출력 계산
        group_output = batched_mul(attention_weights, value)
        
        # 결과를 출력 텐서에 저장
        start_idx = (g-1) * group_size + 1
        end_idx = g * group_size
        output[:, start_idx:end_idx, :] = group_output
    end
    
    return output
end

# 배치 행렬 곱셈을 위한 헬퍼 함수
function batched_mul(a, b)
    return BatchedMultiply()(a, b)
end

# Softmax 구현
function softmax(x; dims=1)
    exp_x = exp.(x .- maximum(x, dims=dims))
    return exp_x ./ sum(exp_x, dims=dims)
end

# 배치 행렬 곱셈을 위한 커스텀 레이어
struct BatchedMultiply end

function (::BatchedMultiply)(a, b)
    return batched_multiply(a, b)
end

# 실제 배치 행렬 곱셈 연산
function batched_multiply(a, b)
    return einsum("bij,bjk->bik", a, b)
end
```

이 코드는 다음과 같은 주요 특징을 가집니다:

```julia
# 주요 특징:
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 11: Write a Julia function to design a RESTful API endpoint for LLM text generation. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
using HTTP
using JSON3
using Base64

"""
텍스트 생성을 위한 RESTful API 엔드포인트를 구현한 모듈입니다.
텍스트 생성 요청을 처리하고 결과를 반환합니다.
"""
module TextGenerationAPI

# API 설정값
const API_PORT = 8080
const MAX_LENGTH = 1000

"""
텍스트 생성 요청을 처리하는 핸들러 함수입니다.
요청 파라미터:
- prompt: 생성할 텍스트의 시작 프롬프트
- max_length: 생성할 최대 토큰 수 (선택사항)
- temperature: 생성 다양성 조절 파라미터 (선택사항)
"""
function handle_generation(req::HTTP.Request)
    try
        # JSON 요청 파싱
        body = JSON3.read(req.body)
        
        # 필수 파라미터 확인
        if !haskey(body, "prompt")
            return HTTP.Response(400, "프롬프트가 필요합니다")
        end
        
        # 파라미터 추출
        prompt = body.prompt
        max_length = get(body, "max_length", MAX_LENGTH)
        temperature = get(body, "temperature", 1.0)
        
        # 여기에 실제 LLM 텍스트 생성 로직 구현
        # 예시로 간단한 에코 응답만 구현
        generated_text = "입력 프롬프트: $prompt"
        
        # 응답 생성
        response = Dict(
            "generated_text" => generated_text,
            "metadata" => Dict(
                "length" => length(generated_text),
                "temperature" => temperature
            )
        )
        
        return HTTP.Response(200, JSON3.write(response))
        
    catch e
        # 에러 처리
        error_response = Dict(
            "error" => "요청 처리 중 오류가 발생했습니다",
            "details" => string(e)
        )
        return HTTP.Response(500, JSON3.write(error_response))
    end
end

"""
API 서버를 시작하는 함수입니다.
지정된 포트에서 HTTP 요청을 수신합니다.
"""
function start_server()
    router = HTTP.Router()
    
    # POST /generate 엔드포인트 등록
    HTTP.register!(router, "POST", "/generate", handle_generation)
    
    # 서버 시작
    println("서버가 포트 $API_PORT 에서 시작되었습니다...")
    HTTP.serve(router, "0.0.0.0", API_PORT)
end

"""
API 사용 예시를 보여주는 함수입니다.
"""
function example_request()
    url = "http://localhost:$API_PORT/generate"
    headers = ["Content-Type" => "application/json"]
    body = Dict(
        "prompt" => "안녕하세요",
        "max_length" => 100,
        "temperature" => 0.7
    )
    
    response = HTTP.post(url, headers, JSON3.write(body))
    println("응답:", String(response.body))
end

export start_server, example_request

end # module

# 사용 예시:
# TextGenerationAPI.start_server()
# TextGenerationAPI.example_request()
```

위 코드는 텍스트 생성을 위한 기본적인 RESTful API를 구현한 것입니다. 주요 기능은 다음과 같습니다:

### 주요 구성 요소:
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 12: Write a Julia function to implement streaming response generation for LLM APIs. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 LLM API를 위한 스트리밍 응답 생성을 구현하는 Julia 함수입니다:

```julia
using HTTP
using JSON3

"""
스트리밍 응답을 처리하기 위한 타입 정의
"""
mutable struct StreamingResponse
    buffer::IOBuffer
    callback::Function
end

"""
LLM API로부터 스트리밍 응답을 처리하는 메인 함수
params:
    - api_url: API 엔드포인트 URL
    - headers: HTTP 요청 헤더
    - payload: API 요청 페이로드
    - callback: 각 청크를 처리하는 콜백 함수
"""
function stream_llm_response(api_url::String, headers::Dict, payload::Dict, callback::Function)
    # 스트리밍 응답 객체 초기화
    streaming_response = StreamingResponse(IOBuffer(), callback)
    
    try
        # HTTP POST 요청 실행
        HTTP.post(api_url, headers, JSON3.write(payload); response_stream=streaming_response.buffer) do response
            process_stream(streaming_response, response)
        end
    catch e
        # 에러 처리
        @error "스트리밍 처리 중 에러 발생" exception=(e, catch_backtrace())
    end
end

"""
스트리밍 데이터를 처리하는 내부 함수
"""
function process_stream(streaming_response::StreamingResponse, response::HTTP.Response)
    buffer = streaming_response.buffer
    
    # 버퍼에서 데이터를 읽어 처리
    while !eof(buffer)
        line = readline(buffer)
        
        # 빈 라인 건너뛰기
        isempty(line) && continue
        
        # "data: " 프리픽스 확인
        startswith(line, "data: ") || continue
        
        # 데이터 파싱 및 처리
        try
            chunk = line[6:end] # "data: " 이후의 데이터
            if chunk != "[DONE]"
                data = JSON3.read(chunk)
                # 콜백 함수 호출
                streaming_response.callback(data)
            end
        catch e
            @warn "청크 처리 중 에러 발생" chunk=line exception=e
        end
    end
end

"""
사용 예시
"""
function example_usage()
    # API 설정
    api_url = "https://api.example.com/v1/completions"
    headers = Dict(
        "Content-Type" => "application/json",
        "Authorization" => "Bearer your-api-key"
    )
    payload = Dict(
        "model" => "gpt-3.5-turbo",
        "prompt" => "Hello, world!",
        "stream" => true
    )
    
    # 콜백 함수 정의
    function handle_chunk(data)
        # 각 청크에서 텍스트 추출 및 처리
        if haskey(data, "choices") && length(data.choices) > 0
            content = data.choices[1].text
            println("받은 텍스트: ", content)
        end
    end
    
    # 스트리밍 시작
    stream_llm_response(api_url, headers, payload, handle_chunk)
end
```

주요 설명:

1. `StreamingResponse` 구조체:
   - 스트리밍 데이터를 저장할 버퍼와 콜백 함수를 포함합니다.

2. `stream_llm_response` 함수:
   - API 요청을 초기화하고 스트리밍을 시작합니다.
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 13: Write a Julia function to handle batch inference requests with queue management. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 배치 추론 요청을 처리하기 위한 모듈
module BatchInferenceQueue

using DataStructures

# 추론 요청을 나타내는 구조체
struct InferenceRequest
    id::String                # 요청 고유 ID
    data::Array              # 입력 데이터
    timestamp::Float64       # 요청 시간
    priority::Int            # 우선순위 (높을수록 먼저 처리)
end

# 배치 추론 큐 관리자 구조체 
mutable struct QueueManager
    queue::PriorityQueue     # 우선순위 큐
    batch_size::Int          # 배치 크기
    max_wait_time::Float64   # 최대 대기 시간(초)
    last_process_time::Float64 # 마지막 처리 시간
end

"""
큐 관리자 초기화 함수
batch_size: 한번에 처리할 배치 크기
max_wait_time: 최대 대기 허용 시간
"""
function init_queue_manager(batch_size::Int, max_wait_time::Float64)
    return QueueManager(
        PriorityQueue{InferenceRequest, Float64}(),
        batch_size,
        max_wait_time,
        time()
    )
end

"""
새로운 추론 요청을 큐에 추가
manager: 큐 관리자
request: 추론 요청 객체
"""
function add_request!(manager::QueueManager, request::InferenceRequest)
    # 우선순위 점수 계산 (우선순위와 시간 기반)
    priority_score = -1.0 * (request.timestamp + 1000.0/request.priority)
    enqueue!(manager.queue, request, priority_score)
end

"""
배치 처리가 필요한지 확인하는 함수
manager: 큐 관리자
returns: 처리 필요 여부
"""
function should_process_batch(manager::QueueManager)
    current_time = time()
    
    # 큐가 비어있으면 처리하지 않음
    if isempty(manager.queue)
        return false
    end
    
    # 배치 크기에 도달했거나 최대 대기 시간 초과시 처리
    return length(manager.queue) >= manager.batch_size ||
           (current_time - manager.last_process_time) >= manager.max_wait_time
end

"""
배치 처리 실행 함수
manager: 큐 관리자
model: 추론에 사용할 모델
returns: 처리된 배치 결과
"""
function process_batch!(manager::QueueManager, model)
    batch = InferenceRequest[]
    batch_data = []
    
    # 배치 크기만큼 또는 큐가 빌 때까지 요청 처리
    while !isempty(manager.queue) && length(batch) < manager.batch_size
        request = dequeue!(manager.queue)
        push!(batch, request)
        push!(batch_data, request.data)
    end
    
    # 배치 데이터로 추론 수행
    if !isempty(batch)
        results = model(batch_data) # 모델 추론 실행
        manager.last_process_time = time()
        return zip(batch, results)
    end
    
    return []
end

"""
사용 예시:
```julia
# 큐 관리자 초기화
manager = init_queue_manager(32, 0.5)  # 배치크기 32, 최대 대기시간 0.5초

# 요청 추가
request = InferenceRequest("req1
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 14: Write a Julia function to implement request rate limiting and authentication for LLM API. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 LLM API를 위한 요청 속도 제한(rate limiting)과 인증을 구현하는 Julia 함수입니다:

```julia
using Dates
using JSON

"""
API 요청을 추적하기 위한 구조체
- token: API 인증 토큰
- requests: 요청 시간 기록을 저장하는 배열
- max_requests: 시간당 최대 요청 수
- time_window: 시간 창 (초 단위)
"""
mutable struct RateLimiter
    token::String
    requests::Vector{DateTime}
    max_requests::Int
    time_window::Int
end

"""
인증 토큰을 검증하는 함수
"""
function validate_token(token::String)
    # 실제 환경에서는 보안 토큰 검증 로직 구현 필요
    return length(token) > 0
end

"""
요청이 속도 제한을 초과하는지 확인하는 함수
"""
function is_rate_limited(limiter::RateLimiter)
    current_time = now()
    # 시간 창 이전의 요청들을 필터링
    filter!(req -> current_time - req < Millisecond(limiter.time_window * 1000), limiter.requests)
    
    return length(limiter.requests) >= limiter.max_requests
end

"""
LLM API 요청을 처리하는 주요 함수
"""
function process_llm_request(limiter::RateLimiter, request_data::Dict)
    try
        # 토큰 유효성 검사
        if !validate_token(limiter.token)
            return Dict(
                "status" => "error",
                "message" => "인증 토큰이 유효하지 않습니다."
            )
        end

        # 속도 제한 검사
        if is_rate_limited(limiter)
            return Dict(
                "status" => "error",
                "message" => "요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요."
            )
        end

        # 요청 시간 기록
        push!(limiter.requests, now())

        # 여기에 실제 LLM API 호출 로직 구현
        # 예시 응답
        return Dict(
            "status" => "success",
            "message" => "요청이 성공적으로 처리되었습니다.",
            "data" => request_data
        )

    catch e
        return Dict(
            "status" => "error",
            "message" => "요청 처리 중 오류가 발생했습니다: $(e)"
        )
    end
end

"""
사용 예시
"""
function example_usage()
    # RateLimiter 초기화 (시간당 100개 요청 제한)
    limiter = RateLimiter(
        "example_api_token",  # API 토큰
        DateTime[],           # 요청 기록
        100,                 # 최대 요청 수
        3600                 # 시간 창 (1시간)
    )

    # 테스트 요청
    request = Dict(
        "prompt" => "안녕하세요",
        "max_tokens" => 100
    )

    # API 요청 처리
    response = process_llm_request(limiter, request)
    println(JSON.json(response, 2))
end
```

주요 특징 설명:

1. `RateLimiter` 구조체:
   - API 토큰 관리
   - 요청 기록 추적
   - 시간당 최대 요청 수 제
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 15: Write a Julia function to log and monitor LLM API usage metrics. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 LLM API 사용 지표를 로깅하고 모니터링하는 Julia 함수입니다:

```julia
using Dates
using JSON

"""
LLM API 사용 지표를 저장하기 위한 구조체
"""
struct APIMetric
    timestamp::DateTime    # API 호출 시간
    model::String         # 사용된 모델명
    tokens_in::Int        # 입력 토큰 수
    tokens_out::Int       # 출력 토큰 수
    latency::Float64      # 응답 시간(초)
    status::String        # 성공/실패 상태
    cost::Float64         # API 호출 비용
end

"""
API 사용 지표를 저장하고 관리하는 타입
"""
mutable struct APIMonitor
    metrics::Vector{APIMetric}
    log_file::String
end

"""
새로운 API 모니터 인스턴스 생성
"""
function create_api_monitor(log_file::String="api_metrics.log")
    return APIMonitor(APIMetric[], log_file)
end

"""
새로운 API 호출 지표를 기록
params:
    - monitor: APIMonitor 인스턴스
    - metric: 기록할 API 지표
"""
function log_metric!(monitor::APIMonitor, metric::APIMetric)
    # 메트릭을 배열에 추가
    push!(monitor.metrics, metric)
    
    # 로그 파일에 저장
    open(monitor.log_file, "a") do f
        metric_dict = Dict(
            "timestamp" => string(metric.timestamp),
            "model" => metric.model,
            "tokens_in" => metric.tokens_in,
            "tokens_out" => metric.tokens_out,
            "latency" => metric.latency,
            "status" => metric.status,
            "cost" => metric.cost
        )
        println(f, JSON.json(metric_dict))
    end
end

"""
특정 기간 동안의 총 비용 계산
params:
    - monitor: APIMonitor 인스턴스
    - start_date: 시작 날짜
    - end_date: 종료 날짜
"""
function calculate_cost_for_period(monitor::APIMonitor, 
                                 start_date::DateTime, 
                                 end_date::DateTime)
    total_cost = 0.0
    for metric in monitor.metrics
        if start_date <= metric.timestamp <= end_date
            total_cost += metric.cost
        end
    end
    return total_cost
end

"""
사용 통계 요약 생성
"""
function generate_usage_summary(monitor::APIMonitor)
    total_calls = length(monitor.metrics)
    total_cost = sum(m.metric.cost for m in monitor.metrics)
    total_tokens = sum(m.tokens_in + m.tokens_out for m in monitor.metrics)
    avg_latency = mean(m.latency for m in monitor.metrics)
    
    return Dict(
        "total_calls" => total_calls,
        "total_cost" => total_cost,
        "total_tokens" => total_tokens,
        "average_latency" => avg_latency
    )
end

# 사용 예시
function example_usage()
    # 모니터 생성
    monitor = create_api_monitor()
    
    # 샘플 메트릭 기록
    metric = APIMetric(
        now(),
        "gpt-4",
        100,
        50,
        0.5,
        "success",
        0.02
    )
    log_metric!(monitor, metric)
    
    # 통계 확인
    summary = generate_usage_summary(monitor)
    println("API 사용 통계:")
    println(summary)
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 16: Write a Julia function to implement model quantization for memory optimization. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function for model quantization with Korean comments:

```julia
# 모델 양자화(Quantization) 구현을 위한 함수들

"""
양자화된 값의 범위를 정의하는 구조체
min_val: 최소값
max_val: 최대값
scale: 스케일 팩터
zero_point: 제로 포인트
"""
struct QuantizationParams
    min_val::Float32
    max_val::Float32
    scale::Float32
    zero_point::Int32
end

"""
텐서를 8비트 정수로 양자화하는 함수
params: 양자화 파라미터
tensor: 입력 텐서
"""
function quantize_tensor(tensor::Array{Float32}, params::QuantizationParams)
    # 부동소수점 값을 정수로 변환
    quantized = round.(Int8, (tensor ./ params.scale) .+ params.zero_point)
    # 8비트 범위로 클리핑 (-128 to 127)
    return clamp.(quantized, -128, 127)
end

"""
8비트 정수를 원래의 부동소수점으로 역양자화하는 함수
quantized: 양자화된 텐서
params: 양자화 파라미터
"""
function dequantize_tensor(quantized::Array{Int8}, params::QuantizationParams)
    # 정수값을 부동소수점으로 복원
    return Float32.((quantized .- params.zero_point) .* params.scale)
end

"""
주어진 텐서에 대한 양자화 파라미터를 계산하는 함수
tensor: 입력 텐서
"""
function calculate_quantization_params(tensor::Array{Float32})
    # 텐서의 최소/최대값 계산
    min_val = minimum(tensor)
    max_val = maximum(tensor)
    
    # 8비트 양자화를 위한 스케일 계산
    scale = (max_val - min_val) / 255.0
    
    # 제로 포인트 계산
    zero_point = round(Int32, -min_val / scale)
    
    return QuantizationParams(min_val, max_val, scale, zero_point)
end

"""
전체 모델 양자화를 수행하는 메인 함수
model_weights: 모델의 가중치들
"""
function quantize_model(model_weights::Dict{String, Array{Float32}})
    # 결과를 저장할 딕셔너리 초기화
    quantized_weights = Dict{String, Array{Int8}}()
    params_dict = Dict{String, QuantizationParams}()
    
    # 각 레이어의 가중치에 대해 양자화 수행
    for (layer_name, weights) in model_weights
        # 양자화 파라미터 계산
        params = calculate_quantization_params(weights)
        params_dict[layer_name] = params
        
        # 가중치 양자화
        quantized = quantize_tensor(weights, params)
        quantized_weights[layer_name] = quantized
    end
    
    return quantized_weights, params_dict
end

# 사용 예시
function example_usage()
    # 샘플 모델 가중치 생성
    sample_weights = Dict(
        "layer1" => rand(Float32, 100, 100),
        "layer2" => rand(Float32, 50, 50)
    )
    
    # 모델 양자화 수행
    quantized_weights, params = quantize_model(sample_weights)
    
    # 첫 번째 레이어의 메모리 사용량 비
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 17: Write a Julia function to perform KV-cache optimization for faster inference. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function implementing KV-cache optimization with Korean comments:

```julia
"""
KV 캐시를 사용하여 Transformer 모델의 추론 속도를 최적화하는 구현
"""
struct KVCache
    # 키(Key) 캐시를 저장하는 배열
    keys::Array{Float32, 4}
    # 값(Value) 캐시를 저장하는 배열
    values::Array{Float32, 4}
end

"""
KV 캐시 초기화 함수
batch_size: 배치 크기
num_heads: 어텐션 헤드 수
head_dim: 각 헤드의 차원
max_seq_length: 최대 시퀀스 길이
"""
function initialize_kv_cache(batch_size::Int, num_heads::Int, head_dim::Int, max_seq_length::Int)
    # 캐시 메모리 할당
    keys = zeros(Float32, batch_size, num_heads, head_dim, max_seq_length)
    values = zeros(Float32, batch_size, num_heads, head_dim, max_seq_length)
    
    return KVCache(keys, values)
end

"""
KV 캐시를 업데이트하고 어텐션 계산을 수행하는 함수
query: 현재 쿼리
cache: KV 캐시
position: 현재 위치
key_proj: 키 프로젝션 가중치
value_proj: 값 프로젝션 가중치
"""
function update_and_attend(
    query::Array{Float32}, 
    cache::KVCache, 
    position::Int,
    key_proj::Array{Float32},
    value_proj::Array{Float32}
)
    # 현재 입력에 대한 키와 값 계산
    current_key = key_proj * query
    current_value = value_proj * query
    
    # 캐시 업데이트
    cache.keys[:,:,:,position] = current_key
    cache.values[:,:,:,position] = current_value
    
    # 현재 위치까지의 캐시된 키와 값 추출
    cached_keys = @view cache.keys[:,:,:,1:position]
    cached_values = @view cache.values[:,:,:,1:position]
    
    # 어텐션 스코어 계산
    attention_scores = batched_multiply(query, cached_keys)
    attention_scores = softmax(attention_scores ./ sqrt(size(query, 1)))
    
    # 최종 출력 계산
    output = batched_multiply(attention_scores, cached_values)
    
    return output
end

"""
배치 행렬 곱셈을 수행하는 헬퍼 함수
"""
function batched_multiply(a::Array{Float32}, b::Array{Float32})
    # BLAS 사용하여 효율적인 행렬 곱셈 수행
    return batched_gemm('N', 'T', 1.0f0, a, b)
end

"""
추론 실행 예시
"""
function inference_example()
    # 모델 파라미터 설정
    batch_size = 1
    num_heads = 12
    head_dim = 64
    max_seq_length = 1024
    
    # KV 캐시 초기화
    cache = initialize_kv_cache(batch_size, num_heads, head_dim, max_seq_length)
    
    # 입력 시퀀스에 대해 순차적으로 처리
    for position in 1:max_seq_length
        # 현재 토큰에 대한 처리
        current_token = get_next_token()  # 
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 18: Write a Julia function to implement dynamic batching for throughput optimization. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 동적 배치 처리를 위한 모듈
module DynamicBatcher

# 필요한 패키지 임포트
using DataStructures

"""
배치 작업을 위한 구조체
- max_batch_size: 최대 배치 크기
- timeout: 배치 대기 시간(초)
- queue: 작업 대기열
"""
mutable struct BatchProcessor
    max_batch_size::Int
    timeout::Float64
    queue::Queue{Any}
    last_process_time::Float64

    function BatchProcessor(max_size::Int, timeout::Float64)
        new(max_size, timeout, Queue{Any}(), time())
    end
end

"""
새로운 작업을 배치 큐에 추가
- processor: BatchProcessor 인스턴스
- item: 처리할 작업 아이템
"""
function add_item!(processor::BatchProcessor, item)
    enqueue!(processor.queue, item)
    process_if_ready!(processor)
end

"""
배치 처리 조건 확인 및 실행
- 큐 크기가 max_batch_size에 도달하거나
- timeout 시간이 경과한 경우 처리 실행
"""
function process_if_ready!(processor::BatchProcessor)
    current_time = time()
    queue_size = length(processor.queue)
    
    # 처리 조건 확인
    if queue_size >= processor.max_batch_size || 
       (queue_size > 0 && current_time - processor.last_process_time >= processor.timeout)
        process_batch!(processor)
    end
end

"""
배치 작업 실행
- 현재 큐에 있는 모든 아이템을 처리
"""
function process_batch!(processor::BatchProcessor)
    batch = Any[]
    
    # 큐에서 아이템 추출
    while !isempty(processor.queue)
        push!(batch, dequeue!(processor.queue))
    end
    
    if !isempty(batch)
        # 실제 배치 처리 로직 실행
        process_items(batch)
        processor.last_process_time = time()
    end
end

"""
실제 배치 처리를 수행하는 함수
- 사용자 정의 처리 로직으로 교체 가능
"""
function process_items(batch)
    println("배치 처리 시작: $(length(batch)) 개의 아이템")
    # 여기에 실제 처리 로직 구현
    for item in batch
        println("아이템 처리: $item")
    end
end

"""
사용 예제
"""
function example_usage()
    # 배치 프로세서 생성 (최대 크기: 5, 타임아웃: 2초)
    processor = BatchProcessor(5, 2.0)
    
    # 테스트 아이템 추가
    for i in 1:10
        add_item!(processor, "item_$i")
        sleep(0.5) # 아이템 추가 간 지연
    end
    
    # 남은 아이템 처리
    process_batch!(processor)
end

end # module

```

이 코드는 동적 배치 처리 시스템을 구현한 것입니다. 주요 특징과 구성 요소는 다음과 같습니다:

### 주요 구성 요소 설명:

1. **BatchProcessor 구조체**
- max_batch_size: 한 번에 처리할 수 있는 최대 아이템 수
- timeout: 배치 처리 대기 최대 시간
- queue: 처리 대기 중인 아이템을 저
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 19: Write a Julia function to monitor GPU memory usage during LLM inference. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 GPU 메모리 사용량을 모니터링하는 Julia 함수입니다:

```julia
using CUDA
using Dates

"""
GPU 메모리 사용량을 모니터링하는 함수
interval: 체크 간격 (초)
duration: 전체 모니터링 시간 (초), 기본값은 60초
"""
function monitor_gpu_memory(interval::Float64=1.0, duration::Float64=60.0)
    # GPU 사용 가능 여부 확인
    if !CUDA.functional()
        println("GPU를 찾을 수 없습니다!")
        return
    }

    # 모니터링 시작 시간
    start_time = now()
    
    # 결과를 저장할 배열
    timestamps = DateTime[]
    memory_used = Float64[]
    memory_free = Float64[]
    
    while (now() - start_time).value/1000 < duration
        # 현재 GPU 메모리 상태 가져오기
        mem_info = CUDA.memory_status()
        
        # 메모리 사용량을 GB 단위로 변환
        used_memory_gb = mem_info.used / 1024^3
        free_memory_gb = mem_info.free / 1024^3
        
        # 데이터 저장
        push!(timestamps, now())
        push!(memory_used, used_memory_gb)
        push!(memory_free, free_memory_gb)
        
        # 현재 상태 출력
        println("시간: $(now())")
        println("사용 중인 메모리: $(round(used_memory_gb, digits=2)) GB")
        println("사용 가능한 메모리: $(round(free_memory_gb, digits=2)) GB")
        println("------------------------")
        
        # 지정된 간격만큼 대기
        sleep(interval)
    end
    
    return (timestamps=timestamps, 
            memory_used=memory_used, 
            memory_free=memory_free)
end

"""
메모리 사용량 통계를 계산하는 함수
monitoring_data: monitor_gpu_memory 함수의 반환값
"""
function calculate_memory_stats(monitoring_data)
    used_memory = monitoring_data.memory_used
    
    # 기본 통계 계산
    max_usage = maximum(used_memory)
    min_usage = minimum(used_memory)
    avg_usage = mean(used_memory)
    
    println("메모리 사용량 통계:")
    println("최대 사용량: $(round(max_usage, digits=2)) GB")
    println("최소 사용량: $(round(min_usage, digits=2)) GB")
    println("평균 사용량: $(round(avg_usage, digits=2)) GB")
    
    return (max=max_usage, min=min_usage, avg=avg_usage)
end

# 사용 예시:
# data = monitor_gpu_memory(1.0, 30.0)  # 30초 동안 1초 간격으로 모니터링
# stats = calculate_memory_stats(data)  # 통계 계산
```

주요 기능 설명:
- `monitor_gpu_memory`: 
  - GPU 메모리 사용량을 주기적으로 모니터링
  - 메모리 사용량을 GB 단위로 변환하여 표시
  - 시간, 사용 중인 메모리, 사용 가능한 메모리를 추적

- `calculate_memory_stats`:
  - 수집된 메모리 사용량 데이터의 통계를 계산
  - 최대, 최소, 평균 사용량을 계산하여 반
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 20: Write a Julia function to implement model warming and preloading strategies. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 Julia에서 모델 워밍업과 프리로딩 전략을 구현하는 함수들입니다:

```julia
using CUDA  # GPU 지원을 위한 CUDA 패키지
using Flux  # 딥러닝 프레임워크

"""
모델 워밍업과 프리로딩을 위한 유틸리티 함수들을 포함하는 모듈
"""
module ModelPreloader

export warmup_model, preload_weights, initialize_cache

"""
모델을 워밍업하는 함수
입력:
- model: 워밍업할 모델
- input_shape: 입력 데이터의 shape
- num_iterations: 워밍업 반복 횟수
"""
function warmup_model(model, input_shape, num_iterations=3)
    # 더미 데이터 생성
    dummy_data = rand(Float32, input_shape...)
    
    # GPU가 사용 가능한 경우 데이터를 GPU로 이동
    if CUDA.functional()
        dummy_data = dummy_data |> gpu
        model = model |> gpu
    end
    
    # 워밍업 실행
    println("모델 워밍업 시작...")
    for i in 1:num_iterations
        model(dummy_data)  # 순전파 실행
        println("워밍업 반복 $i/$num_iterations 완료")
    end
    println("모델 워밍업 완료")
    
    return model
end

"""
모델 가중치를 미리 로드하는 함수
입력:
- model: 대상 모델
- weights_path: 가중치 파일 경로
"""
function preload_weights(model, weights_path)
    try
        # 가중치 파일이 존재하는지 확인
        if !isfile(weights_path)
            error("가중치 파일을 찾을 수 없습니다: $weights_path")
        end
        
        println("가중치 로딩 시작...")
        weights = Dict{String, Any}()
        
        # 가중치 로드 (여기서는 예시로 BSON 형식 사용)
        weights = BSON.load(weights_path)
        
        # 모델에 가중치 적용
        Flux.loadparams!(model, weights)
        
        println("가중치 로딩 완료")
        return true
    catch e
        println("가중치 로딩 중 오류 발생: ", e)
        return false
    end
end

"""
모델의 캐시를 초기화하는 함수
입력:
- model: 대상 모델
- cache_size: 캐시 크기
"""
function initialize_cache(model, cache_size=1000)
    println("모델 캐시 초기화 시작...")
    
    # 캐시 딕셔너리 생성
    model_cache = Dict{String, Any}()
    
    # 모델 파라미터 캐싱
    for (name, param) in pairs(Flux.params(model))
        model_cache[string(name)] = param
    end
    
    println("모델 캐시 초기화 완료")
    return model_cache
end

"""
전체 모델 프리로딩 프로세스를 실행하는 함수
"""
function full_preload_process(model, input_shape, weights_path; 
                            warmup_iterations=3, cache_size=1000)
    # 1. 가중치 프리로딩
    weights_loaded = preload_weights(model, weights_path)
    if !weights_loaded
        return nothing
    end
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 21: Write a Julia function to create unit tests for LLM output quality metrics. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
using Test

"""
LLM 출력 품질 메트릭스를 테스트하는 함수들의 모음입니다.
주요 메트릭스:
- 정확도 (Accuracy)
- 일관성 (Consistency) 
- 관련성 (Relevance)
- 유창성 (Fluency)
"""
module LLMQualityTests

# 정확도를 측정하는 함수
"""
입력된 텍스트가 사실과 일치하는지 확인합니다.
참조 텍스트와 비교하여 정확도 점수를 반환합니다.
"""
function test_accuracy(generated_text::String, reference_text::String)
    # 단어 단위로 비교
    gen_words = split(lowercase(generated_text))
    ref_words = split(lowercase(reference_text))
    
    matches = 0
    total = length(ref_words)
    
    for word in gen_words
        if word in ref_words
            matches += 1
        end
    end
    
    return matches / total
end

# 일관성을 측정하는 함수 
"""
여러 출력 결과들 간의 일관성을 검사합니다.
유사도 점수를 반환합니다.
"""
function test_consistency(outputs::Vector{String})
    if length(outputs) < 2
        return 1.0  # 단일 출력은 완벽히 일관적으로 간주
    end
    
    consistency_scores = Float64[]
    
    for i in 1:length(outputs)
        for j in (i+1):length(outputs)
            # 간단한 문자열 유사도 계산
            similarity = length(intersect(outputs[i], outputs[j])) / 
                        length(union(outputs[i], outputs[j]))
            push!(consistency_scores, similarity)
        end
    end
    
    return mean(consistency_scores)
end

# 관련성을 측정하는 함수
"""
생성된 텍스트가 주어진 프롬프트/컨텍스트와 얼마나 관련있는지 평가합니다.
"""
function test_relevance(generated_text::String, context::String)
    # 컨텍스트의 주요 키워드 추출
    context_keywords = Set(split(lowercase(context)))
    generated_words = Set(split(lowercase(generated_text)))
    
    # 키워드 overlap 계산
    relevance_score = length(intersect(context_keywords, generated_words)) /
                     length(context_keywords)
                     
    return relevance_score
end

# 유창성을 측정하는 함수
"""
텍스트의 문법적 완성도와 자연스러움을 평가합니다.
기본적인 문법 규칙 검사를 수행합니다.
"""
function test_fluency(text::String)
    # 기본적인 문법 체크 항목들
    checks = [
        !isempty(text),  # 비어있지 않음
        occursin(r"[.!?]$", text),  # 적절한 문장 부호로 끝남
        length(split(text)) > 2,  # 최소 단어 수
        occursin(r"^[A-Z]", text)  # 대문자로 시작
    ]
    
    return mean(checks)
end

# 통합 테스트 실행기
"""
모든 품질 메트릭스에 대한 테스트를 실행하고 종합 점수를 반환합니다.
"""
function run_quality_tests(
    generated_text::String,
    reference_text
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 22: Write a Julia function to implement automated prompt template testing. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 프롬프트 템플릿 테스트를 위한 자동화된 함수들을 구현합니다.

"""
    test_prompt_template(template::String, test_cases::Vector{Dict}, expected_outputs::Vector{String})

프롬프트 템플릿을 테스트하는 메인 함수입니다.
- template: 테스트할 프롬프트 템플릿 문자열
- test_cases: 테스트 케이스들의 배열 (각 케이스는 Dict 형태)
- expected_outputs: 기대되는 출력값들의 배열
"""
function test_prompt_template(template::String, test_cases::Vector{Dict}, expected_outputs::Vector{String})
    # 테스트 케이스와 기대 출력값의 개수가 일치하는지 확인
    if length(test_cases) != length(expected_outputs)
        throw(ArgumentError("테스트 케이스와 기대 출력값의 개수가 일치하지 않습니다."))
    end
    
    results = Dict{Int, Bool}()
    failures = Dict{Int, String}()
    
    # 각 테스트 케이스에 대해 실행
    for (i, (test_case, expected)) in enumerate(zip(test_cases, expected_outputs))
        try
            # 템플릿에 테스트 케이스 값을 적용
            actual = apply_template(template, test_case)
            
            # 결과 비교 및 저장
            results[i] = compare_outputs(actual, expected)
            
            if !results[i]
                failures[i] = "기대값: $expected\n실제값: $actual"
            end
            
        catch e
            results[i] = false
            failures[i] = "에러 발생: $e"
        end
    end
    
    return TestResults(results, failures)
end

"""
    apply_template(template::String, variables::Dict)

프롬프트 템플릿에 변수들을 적용하는 함수입니다.
"""
function apply_template(template::String, variables::Dict)
    result = template
    for (key, value) in variables
        # {변수명} 형식의 플레이스홀더를 실제 값으로 대체
        result = replace(result, "{$key}" => value)
    end
    return result
end

"""
    compare_outputs(actual::String, expected::String)

실제 출력값과 기대 출력값을 비교하는 함수입니다.
"""
function compare_outputs(actual::String, expected::String)
    # 기본적인 문자열 비교 (필요에 따라 더 복잡한 비교 로직 추가 가능)
    return strip(actual) == strip(expected)
end

"""
프롬프트 템플릿 테스트 결과를 저장하는 구조체입니다.
"""
struct TestResults
    results::Dict{Int, Bool}  # 각 테스트 케이스의 성공/실패 여부
    failures::Dict{Int, String}  # 실패한 케이스의 상세 정보
end

"""
    print_test_results(results::TestResults)

테스트 결과를 출력하는 함수입니다.
"""
function print_test_results(results::TestResults)
    total = length(results.results)
    passed = count(values(results.results))
    
    println("테스트 결과 요약:")
    println("총 테스트 케이스: $total")
    println("통과: $passed")
    println("실패: $(total - passed)")
    
    if length(results.failures) > 0
        println("\n실패한
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 23: Write a Julia function to evaluate model responses using BLEU/ROUGE scores. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
using ROUGE
using JSON

"""
텍스트 생성 모델의 성능을 BLEU와 ROUGE 점수로 평가하는 함수

매개변수:
- predictions: 모델이 생성한 텍스트 배열
- references: 정답(ground truth) 텍스트 배열  
- output_path: 결과를 저장할 JSON 파일 경로 (선택사항)
"""
function evaluate_generation(predictions::Vector{String}, 
                           references::Vector{String},
                           output_path::Union{String,Nothing}=nothing)
    
    # 입력 검증
    if length(predictions) != length(references)
        throw(ArgumentError("예측값과 정답의 개수가 일치하지 않습니다"))
    end
    
    # ROUGE 점수 계산을 위한 설정
    rouge_scorer = Rouge()
    
    # 각 예측-정답 쌍에 대해 점수 계산
    scores = Dict()
    for (i, (pred, ref)) in enumerate(zip(predictions, references))
        
        # ROUGE 점수 계산
        rouge_scores = score_rouge(pred, ref, rouge_scorer)
        
        # 결과 저장
        scores[string(i)] = Dict(
            "prediction" => pred,
            "reference" => ref,
            "rouge-1" => rouge_scores["rouge-1"],
            "rouge-2" => rouge_scores["rouge-2"], 
            "rouge-l" => rouge_scores["rouge-l"]
        )
    end
    
    # 전체 평균 점수 계산
    avg_scores = Dict(
        "avg_rouge1" => mean([s["rouge-1"] for s in values(scores)]),
        "avg_rouge2" => mean([s["rouge-2"] for s in values(scores)]),
        "avg_rougeL" => mean([s["rouge-l"] for s in values(scores)])
    )
    
    scores["평균_점수"] = avg_scores
    
    # 결과를 JSON 파일로 저장 (경로가 주어진 경우)
    if !isnothing(output_path)
        open(output_path, "w") do f
            JSON.print(f, scores, 2)
        end
        println("평가 결과가 $(output_path)에 저장되었습니다.")
    end
    
    return scores
end

"""
단일 텍스트 쌍에 대한 ROUGE 점수를 계산하는 헬퍼 함수

매개변수:
- prediction: 모델이 생성한 텍스트
- reference: 정답 텍스트
- scorer: ROUGE 계산기 객체
"""
function score_rouge(prediction::String, reference::String, scorer::Rouge)
    # ROUGE-1, ROUGE-2, ROUGE-L 점수 계산
    scores = Dict()
    
    # 각 ROUGE 변형에 대해 F1 점수 계산
    scores["rouge-1"] = scorer.rouge_n(prediction, reference, 1)
    scores["rouge-2"] = scorer.rouge_n(prediction, reference, 2)
    scores["rouge-l"] = scorer.rouge_l(prediction, reference)
    
    return scores
end

# 사용 예시
function example_usage()
    # 테스트 데이터
    predictions = [
        "이것은 테스트 문장입니다.",
        "날씨가 매우 좋습니다."
    ]
    
    references = [
        "이것은 예시 문장입니다.",
        "오늘 날씨가 좋습니다."
    ]
    
    # 평가 실행
    results = evaluate_generation(predictions, references, "결과.json
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 24: Write a Julia function to perform regression testing on LLM model updates. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# LLM 모델 업데이트에 대한 회귀 테스트를 수행하는 함수들입니다.

"""
테스트 케이스와 기대 결과를 저장하는 구조체
"""
struct TestCase
    input::String              # 테스트 입력값
    expected_output::String    # 기대되는 출력값
    category::String          # 테스트 케이스의 카테고리
end

"""
회귀 테스트 결과를 저장하는 구조체
"""
struct TestResult
    passed::Bool              # 테스트 통과 여부
    model_output::String      # 모델이 생성한 실제 출력
    difference::Float64       # 기대값과 실제값의 차이점수
end

"""
LLM 모델 회귀 테스트를 실행하는 주요 함수

Parameters:
- model_old: 이전 모델
- model_new: 새로운 모델 
- test_cases: 테스트 케이스 배열
- threshold: 허용 가능한 차이 임계값
"""
function run_regression_test(model_old, model_new, test_cases::Vector{TestCase}, threshold::Float64=0.9)
    results = Dict{String, Vector{TestResult}}()
    
    # 카테고리별 결과 저장을 위한 딕셔너리 초기화
    for test_case in test_cases
        if !haskey(results, test_case.category)
            results[test_case.category] = TestResult[]
        end
    end
    
    # 각 테스트 케이스에 대해 테스트 실행
    for test_case in test_cases
        # 두 모델에서 결과 생성
        old_output = generate_output(model_old, test_case.input)
        new_output = generate_output(model_new, test_case.input)
        
        # 결과 비교 및 점수 계산
        similarity_score = calculate_similarity(new_output, test_case.expected_output)
        old_similarity = calculate_similarity(old_output, test_case.expected_output)
        
        # 테스트 통과 여부 결정
        passed = (similarity_score >= threshold) && (similarity_score >= old_similarity)
        
        # 결과 저장
        push!(results[test_case.category], 
              TestResult(passed, new_output, similarity_score))
    end
    
    return results
end

"""
테스트 결과를 분석하고 보고서를 생성하는 함수
"""
function generate_test_report(results::Dict{String, Vector{TestResult}})
    println("회귀 테스트 결과 보고서")
    println("=====================")
    
    for (category, test_results) in results
        passed_tests = count(r -> r.passed, test_results)
        total_tests = length(test_results)
        
        println("\n카테고리: $category")
        println("통과율: $(round(passed_tests/total_tests * 100, digits=2))%")
        println("총 테스트: $total_tests")
        println("통과: $passed_tests")
        println("실패: $(total_tests - passed_tests)")
    end
end

"""
두 텍스트 간의 유사도를 계산하는 보조 함수
"""
function calculate_similarity(text1::String, text2::String)
    # 여기에 실제 텍스트 유사도 측정 로직 구현
    # 예: 코사인 유사도, BLEU 점수 등
    return 0.9 # 임시 더미값
end

"""
모델에서 출력을
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 25: Write a Julia function to implement A/B testing framework for prompt variations. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function implementing an A/B testing framework for prompt variations with Korean comments:

```julia
using Statistics
using Random
using Distributions

"""
A/B 테스트를 위한 주요 구조체
- name: 테스트 이름
- variations: 테스트할 프롬프트 변형들
- metrics: 각 변형별 성과 지표
"""
struct ABTest
    name::String
    variations::Vector{String}
    metrics::Dict{String, Vector{Float64}}
end

"""
새로운 A/B 테스트를 생성하는 함수
- name: 테스트 이름
- variations: 테스트할 프롬프트 변형들의 배열
"""
function create_ab_test(name::String, variations::Vector{String})
    metrics = Dict(variation => Float64[] for variation in variations)
    return ABTest(name, variations, metrics)
end

"""
특정 변형에 대한 결과를 기록하는 함수
- test: AB 테스트 객체
- variation: 프롬프트 변형
- score: 성과 점수
"""
function record_result!(test::ABTest, variation::String, score::Float64)
    if variation in test.variations
        push!(test.metrics[variation], score)
    else
        throw(ArgumentError("지정된 변형이 테스트에 존재하지 않습니다"))
    end
end

"""
통계적 유의성을 계산하는 함수
- sample1: 첫 번째 표본
- sample2: 두 번째 표본
- conf_level: 신뢰수준 (기본값 0.95)
"""
function calculate_significance(sample1::Vector{Float64}, sample2::Vector{Float64}, conf_level::Float64=0.95)
    # t-검정을 위한 계산
    n1, n2 = length(sample1), length(sample2)
    m1, m2 = mean(sample1), mean(sample2)
    v1, v2 = var(sample1), var(sample2)
    
    # t-통계량 계산
    pooled_se = sqrt((v1/n1) + (v2/n2))
    t_stat = (m1 - m2) / pooled_se
    
    # 자유도 계산
    df = n1 + n2 - 2
    
    # t-분포를 사용한 p-값 계산
    p_value = 2 * (1 - cdf(TDist(df), abs(t_stat)))
    
    return p_value < (1 - conf_level)
end

"""
A/B 테스트 결과를 분석하고 출력하는 함수
- test: AB 테스트 객체
"""
function analyze_results(test::ABTest)
    println("=== $(test.name) 테스트 결과 ===")
    
    # 각 변형별 기본 통계 계산
    for variation in test.variations
        scores = test.metrics[variation]
        if !isempty(scores)
            println("\n$(variation):")
            println("샘플 수: $(length(scores))")
            println("평균: $(round(mean(scores), digits=3))")
            println("표준편차: $(round(std(scores), digits=3))")
        end
    end
    
    # 변형들 간의 통계적 유의성 검정
    if length(test.variations) >= 2
        println("\n유의성 검정 결과:")
        for i in 1:(length(test.variations)-1)
            for j in (i+1):length(test.variations)
                var1, var2 = test.variations[i], test.variations[j]
                scores1, scores2 = test.metrics[var1], test.metrics[var2]
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 26: Write a Julia function to prepare pre-training data with tokenization and batching. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 사전 학습 데이터를 준비하는 Julia 함수입니다. 토큰화와 배치 처리를 포함합니다:

```julia
using WordTokenizers  # 토큰화를 위한 패키지
using Random

"""
텍스트 데이터를 전처리하고 학습을 위한 배치로 변환하는 함수
text_data: 입력 텍스트
vocab_size: 어휘 사전 크기
batch_size: 배치 크기
seq_length: 시퀀스 길이
"""
function prepare_pretraining_data(
    text_data::String;
    vocab_size::Int=10000,
    batch_size::Int=32,
    seq_length::Int=128
)
    # 텍스트 토큰화
    tokens = wordtokenize(text_data)
    
    # 고유 토큰 추출 및 빈도수 계산
    token_freq = Dict{String, Int}()
    for token in tokens
        token_freq[token] = get(token_freq, token, 0) + 1
    end
    
    # 가장 빈번한 토큰들로 어휘 사전 생성
    sorted_tokens = sort(collect(token_freq), by=x->x[2], rev=true)
    vocabulary = Dict(
        token => i for (i, (token, _)) in enumerate(sorted_tokens[1:min(vocab_size, length(sorted_tokens))])
    )
    
    # 특수 토큰 추가
    vocabulary["<PAD>"] = length(vocabulary) + 1
    vocabulary["<UNK>"] = length(vocabulary) + 1
    
    # 토큰을 인덱스로 변환
    token_indices = map(token -> get(vocabulary, token, vocabulary["<UNK>"]), tokens)
    
    # 배치 생성
    n_batches = div(length(token_indices) - seq_length, batch_size)
    batches = []
    
    for i in 1:n_batches
        batch_start = (i-1) * batch_size + 1
        batch = []
        
        for j in 1:batch_size
            seq_start = batch_start + (j-1)
            seq_end = seq_start + seq_length - 1
            
            # 입력 시퀀스와 타겟 시퀀스 생성
            input_seq = token_indices[seq_start:seq_end]
            target_seq = token_indices[(seq_start+1):(seq_end+1)]
            
            push!(batch, (input_seq, target_seq))
        end
        
        push!(batches, batch)
    end
    
    return batches, vocabulary
end

# 데이터 증강 함수
"""
배치 데이터에 대한 간단한 증강을 수행하는 함수
batch: 입력 배치
mask_prob: 마스킹 확률
"""
function augment_batch(batch, mask_prob::Float64=0.15)
    augmented_batch = []
    
    for (input_seq, target_seq) in batch
        # 랜덤 마스킹 적용
        masked_input = copy(input_seq)
        mask_indices = findall(rand(length(input_seq)) .< mask_prob)
        
        for idx in mask_indices
            masked_input[idx] = vocabulary["<PAD>"]
        end
        
        push!(augmented_batch, (masked_input, target_seq))
    end
    
    return augmented_batch
end

# 사용 예시
"""
text = "긴 텍스트 데이터..."
batches, vocab = prepare_pretraining_data(text)
augmented_batches = map(batch -> augment_batch
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 27: Write a Julia function to implement causal language modeling loss calculation. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 인과적 언어 모델링(Causal Language Modeling)의 손실 계산을 위한 Julia 함수입니다:

```julia
"""
인과적 언어 모델링 손실을 계산하는 함수

입력값:
- logits: 모델의 예측 로짓 (배치 × 어휘크기 × 시퀀스길이)
- targets: 실제 타겟 레이블 (배치 × 시퀀스길이)
- pad_idx: 패딩 토큰의 인덱스 (기본값 = 0)

반환값:
- 평균 손실값 (스칼라)
"""
function causal_language_modeling_loss(logits::Array{Float32, 3}, 
                                     targets::Array{Int64, 2},
                                     pad_idx::Int64=0)
    # 배치 크기, 어휘 크기, 시퀀스 길이 추출
    batch_size, vocab_size, seq_length = size(logits)
    
    # 로짓을 2D로 재구성 (배치×시퀀스길이, 어휘크기)
    logits_2d = reshape(permutedims(logits, (1,3,2)), :, vocab_size)
    
    # 타겟을 1D로 재구성
    targets_1d = reshape(targets, :)
    
    # 패딩 마스크 생성 (패딩이 아닌 위치는 true)
    mask = targets_1d .!= pad_idx
    
    # 크로스 엔트로피 손실 계산
    # log_softmax를 사용하여 수치적 안정성 확보
    log_probs = logsoftmax(logits_2d, dims=2)
    
    # gather 연산 구현 (각 위치에서 정답 토큰의 로그 확률 선택)
    losses = [log_probs[i, targets_1d[i]] for i in 1:length(targets_1d)]
    
    # 마스킹된 위치의 손실만 평균 계산
    masked_losses = losses[mask]
    
    # 최종 손실값 반환 (음수를 취해 최소화 문제로 변환)
    return -mean(masked_losses)
end

"""
도우미 함수: 로그 소프트맥스 계산
"""
function logsoftmax(x::Matrix{Float32}, dims::Int64)
    # 수치적 안정성을 위해 최대값 빼기
    max_x = maximum(x, dims=dims)
    exp_x = exp.(x .- max_x)
    log_sum_exp = log.(sum(exp_x, dims=dims))
    return x .- max_x .- log_sum_exp
end

# 사용 예시
function example_usage()
    # 임의의 입력 데이터 생성
    batch_size, vocab_size, seq_length = 2, 1000, 5
    logits = rand(Float32, batch_size, vocab_size, seq_length)
    targets = rand(1:vocab_size, batch_size, seq_length)
    
    # 손실 계산
    loss = causal_language_modeling_loss(logits, targets)
    println("계산된 손실값: ", loss)
end
```

이 코드에 대한 주요 설명:

1. **함수의 목적**:
   - 이 함수는 언어 모델의 예측과 실제 타겟 간의 크로스 엔트로피 손실을 계산합니다.
   - 
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 28: Write a Julia function to load and preprocess fine-tuning datasets. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 파인튜닝 데이터셋을 로드하고 전처리하는 Julia 함수입니다:

```julia
using DataFrames
using CSV
using Random
using StatsBase

"""
데이터셋 전처리를 위한 주요 함수
입력:
- file_path: 데이터 파일 경로 (CSV 형식)
- text_col: 텍스트 컬럼 이름
- label_col: 레이블 컬럼 이름 (선택사항)
- test_size: 테스트 세트 비율 (기본값: 0.2)
- val_size: 검증 세트 비율 (기본값: 0.1)
"""
function load_and_preprocess_dataset(
    file_path::String;
    text_col::String,
    label_col::Union{String,Nothing}=nothing,
    test_size::Float64=0.2,
    val_size::Float64=0.1
)
    # CSV 파일 로드
    df = CSV.read(file_path, DataFrame)
    
    # 필수 컬럼 확인
    if !(text_col in names(df))
        throw(ArgumentError("텍스트 컬럼을 찾을 수 없습니다: $text_col"))
    end
    
    # 텍스트 전처리
    df[!, text_col] = preprocess_text.(df[!, text_col])
    
    # 데이터셋 분할
    return split_dataset(df, text_col, label_col, test_size, val_size)
end

"""
텍스트 전처리를 위한 보조 함수
- 소문자 변환
- 특수문자 제거
- 여러 공백을 하나로 통일
"""
function preprocess_text(text::String)
    # 소문자 변환
    text = lowercase(text)
    
    # 특수문자 제거 (기본적인 구두점 유지)
    text = replace(text, r"[^a-z0-9\s\.,!?]" => "")
    
    # 연속된 공백 제거
    text = replace(text, r"\s+" => " ")
    
    # 앞뒤 공백 제거
    return strip(text)
end

"""
데이터셋을 훈련/검증/테스트 세트로 분할하는 함수
"""
function split_dataset(
    df::DataFrame,
    text_col::String,
    label_col::Union{String,Nothing},
    test_size::Float64,
    val_size::Float64
)
    # 전체 데이터 크기
    n = nrow(df)
    
    # 인덱스 생성
    indices = shuffle(1:n)
    
    # 분할 지점 계산
    test_idx = floor(Int, n * (1 - test_size))
    val_idx = floor(Int, test_idx * (1 - val_size))
    
    # 데이터셋 분할
    train_indices = indices[1:val_idx]
    val_indices = indices[(val_idx+1):test_idx]
    test_indices = indices[(test_idx+1):end]
    
    # 결과 저장을 위한 딕셔너리
    result = Dict(
        "train" => Dict("texts" => df[train_indices, text_col]),
        "val" => Dict("texts" => df[val_indices, text_col]),
        "test" => Dict("texts" => df[test_indices, text_col])
    )
    
    # 레이블이 있는 경우 추가
    if !isnothing(label_col)
        if label_col in names(df)
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 29: Write a Julia function to implement LoRA (Low-Rank Adaptation) for parameter-efficient fine-tuning. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia implementation of LoRA with Korean comments:

```julia
using Flux
using LinearAlgebra

"""
LoRA (Low-Rank Adaptation) 구현을 위한 구조체
- original_layer: 원본 가중치 행렬
- rank: LoRA의 순위 (rank)
- alpha: 스케일링 파라미터
- A: 하위 행렬 A
- B: 하위 행렬 B
"""
mutable struct LoRALayer
    original_layer::Dense
    rank::Int
    alpha::Float32
    A::Matrix{Float32}
    B::Matrix{Float32}
end

"""
LoRA 레이어 초기화 함수
- layer: 원본 Dense 레이어
- rank: 저차원 근사의 순위
- alpha: 스케일링 파라미터
- init_scale: 초기화 스케일
"""
function init_lora(layer::Dense, rank::Int; alpha::Float32=1.0f0, init_scale::Float32=1.0f0)
    out_dim, in_dim = size(layer.weight)
    
    # A와 B 행렬 초기화 (정규분포를 사용하여 랜덤 초기화)
    A = randn(Float32, rank, in_dim) * init_scale / sqrt(rank)
    B = zeros(Float32, out_dim, rank)
    
    return LoRALayer(layer, rank, alpha, A, B)
end

"""
LoRA 레이어의 순전파 (forward pass) 구현
- lora: LoRA 레이어
- x: 입력 텐서
"""
function (lora::LoRALayer)(x)
    # 원본 레이어의 순전파
    original_output = lora.original_layer(x)
    
    # LoRA 적용: ΔW = BA
    lora_output = (lora.B * lora.A * x) * (lora.alpha / lora.rank)
    
    # 최종 출력: 원본 출력 + LoRA 출력
    return original_output + lora_output
end

"""
학습 가능한 파라미터 반환 함수
- lora: LoRA 레이어
"""
function trainable_params(lora::LoRALayer)
    # LoRA의 A와 B 행렬만 학습 대상
    return Flux.params(lora.A, lora.B)
end

"""
LoRA 사용 예시
"""
function example_usage()
    # 원본 레이어 생성
    original_layer = Dense(768, 768) # 예: BERT의 일반적인 차원
    
    # LoRA 레이어 초기화
    lora_layer = init_lora(original_layer, 8) # rank=8
    
    # 임의의 입력 데이터
    x = randn(Float32, 768, 32) # 배치 크기 32
    
    # 순전파
    output = lora_layer(x)
    
    # 학습 가능한 파라미터 얻기
    params = trainable_params(lora_layer)
    
    return output, params
end

"""
메모리 사용량 계산 함수
- original_params: 원본 모델의 파라미터 수
- lora_params: LoRA의 파라미터 수
"""
function calculate_memory_savings(original_params::Int, lora_params::Int)
    savings = (1 - lora_params / original_params) * 100
    println("메모리 절감률: $(round(savings, digits=2))%")
end
```

이 구현은 다음과 같은 주요 특징을
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 30: Write a Julia function to create instruction-following training examples. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
"""
# 지시사항-응답 쌍을 생성하는 함수들
"""

using Random

"""
지시사항과 응답 쌍을 생성하는 기본 구조체 
"""
struct InstructionExample
    instruction::String  # 지시사항
    response::String    # 응답
end

"""
지시사항-응답 데이터셋을 생성하는 메인 함수
입력:
- n_examples: 생성할 예제 수
- task_types: 과제 유형 목록 (예: ["분류", "요약" 등])
- domains: 도메인 목록 (예: ["일반", "기술" 등])

출력:
- InstructionExample 객체의 벡터
"""
function generate_instruction_examples(n_examples::Int, 
                                    task_types::Vector{String},
                                    domains::Vector{String})
    
    examples = InstructionExample[]  # 결과를 저장할 빈 벡터
    
    for i in 1:n_examples
        # 무작위로 과제 유형과 도메인 선택
        task = rand(task_types)
        domain = rand(domains)
        
        # 선택된 유형과 도메인에 따라 예제 생성
        example = create_single_example(task, domain)
        push!(examples, example)
    end
    
    return examples
end

"""
단일 지시사항-응답 쌍을 생성하는 헬퍼 함수
입력:
- task: 과제 유형
- domain: 도메인

출력:
- InstructionExample 객체
"""
function create_single_example(task::String, domain::String)
    
    # 과제 유형별 템플릿 정의
    templates = Dict(
        "분류" => "다음 텍스트를 $(domain) 카테고리로 분류해주세요: ",
        "요약" => "다음 $(domain) 관련 텍스트를 한 문장으로 요약해주세요: ",
        "번역" => "다음 $(domain) 텍스트를 한국어로 번역해주세요: "
    )
    
    # 기본 템플릿 선택
    instruction_template = get(templates, task, "다음 작업을 수행해주세요: ")
    
    # 실제 지시사항과 응답 생성 
    instruction = instruction_template * generate_sample_text(domain)
    response = generate_sample_response(task, domain)
    
    return InstructionExample(instruction, response)
end

"""
샘플 텍스트를 생성하는 헬퍼 함수
입력:
- domain: 도메인

출력:
- 샘플 텍스트 문자열
"""
function generate_sample_text(domain::String)
    # 실제 구현에서는 더 다양한 텍스트 생성 로직 필요
    return "이것은 $(domain)에 관한 샘플 텍스트입니다."
end

"""
샘플 응답을 생성하는 헬퍼 함수
입력:
- task: 과제 유형
- domain: 도메인

출력:
- 샘플 응답 문자열
"""
function generate_sample_response(task::String, domain::String)
    # 실제 구현에서는 더 정교한 응답 생성 로직 필요
    return "이것은 $(task) 작업에 대한 $(domain) 관련 샘플 응답입니다."
end

# 사용 예시
"""
# 예
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 31: Write a Julia function to implement few-shot prompt template generation. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 퓨샷 프롬프트 템플릿을 생성하는 함수들을 구현합니다

"""
    FewShotExample

퓨샷 학습을 위한 예제를 저장하는 구조체
input: 입력 텍스트
output: 정답/출력 텍스트
"""
struct FewShotExample
    input::String
    output::String
end

"""
    FewShotTemplate

퓨샷 프롬프트 템플릿을 정의하는 구조체
prefix: 프롬프트 시작 부분의 설명/지시문
examples: 퓨샷 예제들의 배열
suffix: 새로운 입력에 대한 지시문
example_separator: 예제들 사이의 구분자
"""
struct FewShotTemplate
    prefix::String
    examples::Vector{FewShotExample}
    suffix::String
    example_separator::String
end

"""
    format_example(example::FewShotExample, input_prefix::String="입력: ", output_prefix::String="출력: ")

단일 퓨샷 예제를 포맷팅하는 함수
"""
function format_example(example::FewShotExample, 
                       input_prefix::String="입력: ",
                       output_prefix::String="출력: ")
    return """
    $input_prefix$(example.input)
    $output_prefix$(example.output)
    """
end

"""
    generate_prompt(template::FewShotTemplate, new_input::String)

새로운 입력에 대한 전체 프롬프트를 생성하는 함수
"""
function generate_prompt(template::FewShotTemplate, new_input::String)
    # 예제들을 포맷팅
    formatted_examples = [format_example(ex) for ex in template.examples]
    
    # 예제들을 구분자로 연결
    examples_text = join(formatted_examples, template.example_separator)
    
    # 전체 프롬프트 조립
    return """
    $(template.prefix)
    
    $(examples_text)
    
    $(template.suffix)
    입력: $new_input
    출력:"""
end

# 사용 예시
function example_usage()
    # 퓨샷 예제 정의
    examples = [
        FewShotExample(
            "이 상품은 매우 좋아요.",
            "긍정"
        ),
        FewShotExample(
            "품질이 많이 실망스럽네요.",
            "부정"
        )
    ]
    
    # 템플릿 정의
    template = FewShotTemplate(
        "다음은 상품 리뷰의 감성을 분류하는 예제입니다.", # 접두사
        examples, # 예제들
        "위의 예제를 참고하여 다음 리뷰의 감성을 분류해주세요.", # 접미사
        "\n---\n" # 예제 구분자
    )
    
    # 새로운 입력에 대한 프롬프트 생성
    new_input = "배송이 빠르고 가격도 합리적이에요."
    prompt = generate_prompt(template, new_input)
    
    return prompt
end
```

이 코드는 퓨샷 프롬프트 템플릿을 생성하는 시스템을 구현합니다. 주요 구성요소와 기능은 다음과 같습니다:

### 주요 구조체:
- `FewShotExample`: 개별 퓨샷 예제를 저장
- `Few
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 32: Write a Julia function to optimize prompts using chain-of-thought reasoning. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function for prompt optimization using chain-of-thought reasoning, with Korean comments:

```julia
# 프롬프트 최적화를 위한 모듈
module PromptOptimizer

# 필요한 패키지 가져오기
using Random
using Statistics

"""
프롬프트 품질 점수를 계산하는 함수
입력: 프롬프트 문자열
출력: 0-1 사이의 품질 점수
"""
function calculate_prompt_score(prompt::String)
    # 기본적인 품질 지표들
    점수 = 0.0
    
    # 길이 적절성 체크 (너무 짧거나 길지 않은지)
    적정_길이 = 50 <= length(prompt) <= 500
    점수 += 적정_길이 ? 0.2 : 0
    
    # 명확한 지시어 포함 여부
    지시어_리스트 = ["설명해주세요", "분석해보면", "단계별로", "이유는"]
    지시어_점수 = sum([contains(prompt, word) for word in 지시어_리스트]) * 0.1
    점수 += min(지시어_점수, 0.3)
    
    # 논리적 연결어 확인
    연결어_리스트 = ["따라서", "그러므로", "왜냐하면", "결과적으로"]
    연결어_점수 = sum([contains(prompt, word) for word in 연결어_리스트]) * 0.1
    점수 += min(연결어_점수, 0.3)
    
    # 질문의 구체성 점수
    구체성_키워드 = ["구체적으로", "예시를", "단계별로"]
    구체성_점수 = sum([contains(prompt, word) for word in 구체성_키워드]) * 0.1
    점수 += min(구체성_점수, 0.2)
    
    return 점수
end

"""
주어진 프롬프트를 최적화하는 함수
입력: 
- base_prompt: 기본 프롬프트
- iterations: 최적화 반복 횟수
출력: 최적화된 프롬프트
"""
function optimize_prompt(base_prompt::String, iterations::Int=5)
    # 현재까지의 최고 프롬프트와 점수 저장
    최고_프롬프트 = base_prompt
    최고_점수 = calculate_prompt_score(base_prompt)
    
    # 개선을 위한 추가 문구들
    개선_문구 = [
        "단계별로 설명해주세요.",
        "이에 대해 구체적인 예시를 들어 설명해주세요.",
        "왜 이렇게 생각하시나요?",
        "이러한 결론에 도달한 과정을 설명해주세요.",
        "각 단계의 논리적 연결성을 보여주세요."
    ]
    
    for i in 1:iterations
        # 랜덤하게 개선 문구 선택
        추가_문구 = rand(개선_문구)
        
        # 새로운 프롬프트 생성
        새_프롬프트 = string(최고_프롬프트, " ", 추가_문구)
        새_점수 = calculate_prompt_score(새_프롬프트)
        
        # 더 나은 결과면 업데이트
        if 새_점수 > 최고_점수
            최고_프
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 33: Write a Julia function to create prompt templates with variable placeholders. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
"""
템플릿 문자열에서 변수를 치환하여 프롬프트를 생성하는 기능을 제공하는 모듈입니다.
"""
module PromptTemplate

export create_template, fill_template

"""
프롬프트 템플릿을 나타내는 구조체입니다.
- template: 변수 플레이스홀더가 포함된 템플릿 문자열
- variables: 템플릿에서 사용되는 변수명 목록
"""
struct Template
    template::String
    variables::Vector{String}
end

"""
템플릿 문자열에서 변수 플레이스홀더를 추출하여 Template 객체를 생성합니다.
변수 플레이스홀더는 {변수명} 형식으로 지정합니다.

예시:
```julia
template = create_template("안녕하세요 {name}님, {time}에 만나요!")
# 변수: ["name", "time"]
```
"""
function create_template(template_str::String)
    # 정규식을 사용하여 {변수명} 형식의 플레이스홀더를 찾습니다
    pattern = r"\{([^{}]+)\}"
    matches = collect(eachmatch(pattern, template_str))
    
    # 변수명을 추출합니다
    variables = [m.captures[1] for m in matches]
    
    return Template(template_str, variables)
end

"""
Template 객체와 변수값을 받아서 완성된 프롬프트 문자열을 생성합니다.

예시:
```julia
template = create_template("안녕하세요 {name}님, {time}에 만나요!")
prompt = fill_template(template, Dict("name" => "홍길동", "time" => "3시"))
# 결과: "안녕하세요 홍길동님, 3시에 만나요!"
```
"""
function fill_template(template::Template, values::Dict{String,Any})
    result = template.template
    
    # 모든 변수가 제공되었는지 확인합니다
    missing_vars = setdiff(Set(template.variables), Set(keys(values)))
    if !isempty(missing_vars)
        throw(ArgumentError("다음 변수가 누락되었습니다: $(join(missing_vars, ", "))"))
    end
    
    # 각 변수를 해당하는 값으로 치환합니다
    for (var, val) in values
        result = replace(result, "{$var}" => string(val))
    end
    
    return result
end

end # module

# 사용 예시:
"""
using PromptTemplate

# 템플릿 생성
template = create_template("안녕하세요 {name}님! 오늘 날씨는 {weather}입니다.")

# 변수값 설정
values = Dict(
    "name" => "홍길동",
    "weather" => "맑음"
)

# 템플릿 채우기
result = fill_template(template, values)
println(result)  # 출력: 안녕하세요 홍길동님! 오늘 날씨는 맑음입니다.
"""
```

위 코드에 대한 설명:

1. **모듈 구성**
- `PromptTemplate` 모듈은 템플릿 기능을 캡슐화합니다
- `Template` 구조체와 두 개의 주요 함수를 제공합니다

2. **주요 기능**
- `create_template`: 템플릿 문자열을 
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 34: Write a Julia function to validate and sanitize user prompts for safety. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 사용자 입력 프롬프트를 검증하고 정제하는 함수들을 포함하는 모듈
module PromptSanitizer

# 금지된 문자와 패턴을 정의
const FORBIDDEN_CHARS = ['<', '>', '$', '|', ';', '&']
const FORBIDDEN_PATTERNS = [
    r"rm\s+-rf", # 시스템 삭제 명령어
    r"sudo",     # 관리자 권한 명령어  
    r"exec\(",   # 코드 실행 함수
    r"eval\("    # 코드 평가 함수
]

"""
    sanitize_prompt(input::String)::String

사용자 입력 문자열을 검사하고 정제합니다.
위험한 문자나 패턴이 발견되면 예외를 발생시킵니다.

# 인수
- `input::String`: 검사할 사용자 입력 문자열

# 반환값
- 정제된 안전한 문자열
"""
function sanitize_prompt(input::String)::String
    # 빈 입력 체크
    if isempty(strip(input))
        throw(ArgumentError("입력값이 비어있습니다"))
    end

    # 길이 제한 체크 
    if length(input) > 1000
        throw(ArgumentError("입력값이 너무 깁니다 (1000자 제한)"))
    end

    # 금지된 문자 체크
    for char in FORBIDDEN_CHARS
        if char in input
            throw(ArgumentError("금지된 문자가 포함되어 있습니다: $char"))
        end
    end

    # 금지된 패턴 체크
    for pattern in FORBIDDEN_PATTERNS
        if occursin(pattern, lowercase(input))
            throw(ArgumentError("금지된 패턴이 포함되어 있습니다: $pattern"))
        end
    end

    # HTML 태그 제거
    sanitized = replace(input, r"<[^>]*>" => "")
    
    # 기본적인 XSS 방지
    sanitized = replace(sanitized, r"(?i)script" => "")
    
    # 연속된 공백 제거
    sanitized = replace(sanitized, r"\s+" => " ")
    
    # 앞뒤 공백 제거
    return strip(sanitized)
end

"""
    is_safe_prompt(input::String)::Bool

입력 문자열이 안전한지 검사합니다.

# 인수
- `input::String`: 검사할 문자열

# 반환값
- 안전하면 true, 그렇지 않으면 false
"""
function is_safe_prompt(input::String)::Bool
    try
        sanitize_prompt(input)
        return true
    catch
        return false
    end
end

# 사용 예시를 위한 테스트 함수
function test_sanitizer()
    # 정상 케이스
    println("정상 입력 테스트:")
    safe_input = "안녕하세요 반갑습니다"
    println(sanitize_prompt(safe_input))

    # 비정상 케이스
    println("\n비정상 입력 테스트:")
    unsafe_inputs = [
        "<script>alert('xss')</script>",
        "rm -rf /",
        "sudo command",
        "eval(code)",
        "&& dangerous command"
    ]

    for input in unsafe_inputs
        result = is_safe_prompt(input)
        println("입력: $input -> 안전함: $result")
    end
end

end # module

# 모듈 사용 예
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 35: Write a Julia function to implement prompt caching for repeated queries. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
using SHA
using JSON

"""
프롬프트 캐싱을 위한 구조체
- cache_dir: 캐시 파일이 저장될 디렉토리 경로
- cache: 메모리상의 캐시를 저장하는 딕셔너리
"""
mutable struct PromptCache
    cache_dir::String
    cache::Dict{String, Any}
    
    function PromptCache(cache_dir::String="./cache")
        # 캐시 디렉토리가 없으면 생성
        !isdir(cache_dir) && mkdir(cache_dir)
        new(cache_dir, Dict{String, Any}())
    end
end

"""
프롬프트와 파라미터로 캐시 키를 생성하는 함수
입력:
- prompt: 프롬프트 문자열
- params: 추가 파라미터 딕셔너리
반환:
- 해시된 캐시 키 문자열
"""
function create_cache_key(prompt::String, params::Dict)
    # 프롬프트와 파라미터를 합쳐서 해시 생성
    content = prompt * json(params)
    return bytes2hex(sha256(content))
end

"""
캐시된 결과를 파일에 저장하는 함수
입력:
- cache: PromptCache 인스턴스
- key: 캐시 키
- value: 저장할 값
"""
function save_cache_to_file(cache::PromptCache, key::String, value::Any)
    cache_file = joinpath(cache.cache_dir, key * ".json")
    open(cache_file, "w") do f
        JSON.print(f, value)
    end
end

"""
파일에서 캐시된 결과를 불러오는 함수
입력:
- cache: PromptCache 인스턴스
- key: 캐시 키
반환:
- 캐시된 값 또는 nothing
"""
function load_cache_from_file(cache::PromptCache, key::String)
    cache_file = joinpath(cache.cache_dir, key * ".json")
    if isfile(cache_file)
        return JSON.parsefile(cache_file)
    end
    return nothing
end

"""
프롬프트 실행 결과를 캐싱하는 메인 함수
입력:
- cache: PromptCache 인스턴스
- prompt: 프롬프트 문자열
- params: 추가 파라미터
- query_func: 실제 쿼리를 수행하는 함수
반환:
- 캐시된 결과 또는 새로운 쿼리 결과
"""
function get_cached_response(
    cache::PromptCache, 
    prompt::String, 
    params::Dict, 
    query_func::Function
)
    # 캐시 키 생성
    cache_key = create_cache_key(prompt, params)
    
    # 메모리 캐시 확인
    if haskey(cache.cache, cache_key)
        return cache.cache[cache_key]
    end
    
    # 파일 캐시 확인
    file_cache = load_cache_from_file(cache, cache_key)
    if file_cache !== nothing
        cache.cache[cache_key] = file_cache
        return file_cache
    end
    
    # 캐시가 없으면 새로 쿼리 실행
    result = query_func(prompt, params)
    
    # 결과를 캐시에 저장
    cache.cache[cache_key] = result
    save_cache_to_file(cache, cache_key, result)
    
    return result
end

# 
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 36: Write a Julia function to initialize a vector database schema with metadata. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 벡터 데이터베이스를 위한 스키마 및 메타데이터 초기화 함수들

"""
벡터 데이터베이스의 기본 구조체 정의
- id: 고유 식별자
- vector: 벡터 데이터
- metadata: 관련 메타데이터
"""
struct VectorEntry
    id::String
    vector::Vector{Float64}
    metadata::Dict{String, Any}
end

"""
데이터베이스 스키마 구조체
- dimensions: 벡터의 차원 수
- metric: 거리 측정 방식 ("cosine", "euclidean" 등)
- entries: 벡터 데이터 저장소
"""
mutable struct VectorDBSchema
    dimensions::Int64
    metric::String 
    entries::Vector{VectorEntry}
end

"""
벡터 데이터베이스 스키마 초기화 함수
- dimensions: 벡터의 차원 수 지정
- metric: 거리 계산 방식 선택
반환값: 초기화된 VectorDBSchema 객체
"""
function init_vector_db_schema(dimensions::Int64, metric::String="cosine")
    # 입력값 검증
    if dimensions <= 0
        throw(ArgumentError("차원 수는 양수여야 합니다"))
    end
    
    if !(metric in ["cosine", "euclidean", "manhattan"])
        throw(ArgumentError("지원되지 않는 거리 측정 방식입니다"))
    end
    
    # 새로운 스키마 생성 및 반환
    return VectorDBSchema(dimensions, metric, VectorEntry[])
end

"""
벡터 데이터 추가 함수
- db: 벡터 데이터베이스 스키마
- vector: 추가할 벡터 데이터
- metadata: 관련 메타데이터
반환값: 성공 여부 (Boolean)
"""
function add_vector_entry!(db::VectorDBSchema, vector::Vector{Float64}, metadata::Dict{String, Any})
    # 벡터 차원 검증
    if length(vector) != db.dimensions
        throw(ArgumentError("벡터 차원이 스키마와 일치하지 않습니다"))
    end
    
    # 고유 ID 생성
    id = string(uuid4())
    
    # 새로운 엔트리 생성
    entry = VectorEntry(id, vector, metadata)
    
    # 데이터베이스에 추가
    push!(db.entries, entry)
    
    return true
end

"""
사용 예시:
```julia
# 데이터베이스 초기화
db = init_vector_db_schema(128) # 128차원 벡터 데이터베이스 생성

# 벡터 데이터 추가
vector = rand(128) # 128차원 랜덤 벡터
metadata = Dict("name" => "test_vector", "category" => "test")
add_vector_entry!(db, vector, metadata)
```
"""

```

위 코드는 벡터 데이터베이스의 기본 스키마를 구현한 것입니다. 주요 기능은 다음과 같습니다:

1. 주요 구조체:
- `VectorEntry`: 개별 벡터 데이터 저장
- `VectorDBSchema`: 전체 데이터베이스 스키마 정의

2. 주요 함수:
- `init_vector_db_schema()`: 데이터베이스 초기화
- `add_vector_entry!()`: 새로운 벡터 데이터 추
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 37: Write a Julia function to perform HNSW (Hierarchical Navigable Small World) indexing. Provide all comments and explanations in Korean (한국어).
Answer: # HNSW (Hierarchical Navigable Small World) 구현
# 근사 최근접 이웃 검색을 위한 그래프 기반 인덱싱 방법

```julia
using LinearAlgebra

"""
HNSW 노드 구조체
- id: 데이터 포인트의 고유 식별자
- vector: 실제 데이터 벡터
- neighbors: 각 레이어별 이웃 노드들의 ID를 저장하는 배열
"""
mutable struct HNSWNode
    id::Int
    vector::Vector{Float64}
    neighbors::Vector{Vector{Int}}
end

"""
HNSW 인덱스 구조체
- nodes: 모든 노드를 저장하는 딕셔너리
- max_layers: 최대 레이어 수
- M: 각 노드의 최대 이웃 수
- ef_construction: 구축 시 탐색할 이웃의 수
"""
mutable struct HNSWIndex
    nodes::Dict{Int, HNSWNode}
    max_layers::Int
    M::Int
    ef_construction::Int
end

"""
두 벡터 간의 유클리드 거리 계산
"""
function euclidean_distance(a::Vector{Float64}, b::Vector{Float64})
    return norm(a - b)
end

"""
새로운 노드의 레이어 레벨 결정
- 기하 분포를 사용하여 무작위로 레벨 선택
"""
function get_random_level(max_layers::Int)
    level = 0
    while rand() < 0.5 && level < max_layers - 1
        level += 1
    end
    return level
end

"""
HNSW 인덱스 초기화
"""
function create_hnsw_index(max_layers::Int=4, M::Int=5, ef_construction::Int=100)
    return HNSWIndex(Dict(), max_layers, M, ef_construction)
end

"""
가장 가까운 이웃들 검색
"""
function search_neighbors(index::HNSWIndex, query::Vector{Float64}, k::Int, layer::Int)
    # 초기 후보 설정
    candidates = Set{Int}()
    distances = Dict{Int, Float64}()
    
    # 시작점 찾기
    entry_point = first(keys(index.nodes))
    
    for node_id in keys(index.nodes)
        if length(index.nodes[node_id].neighbors) > layer
            entry_point = node_id
            break
        end
    end
    
    # 현재 레이어에서 가장 가까운 이웃들 찾기
    current_dist = euclidean_distance(query, index.nodes[entry_point].vector)
    push!(candidates, entry_point)
    distances[entry_point] = current_dist
    
    # 이웃 탐색
    results = []
    while !isempty(candidates)
        current = argmin([distances[c] for c in candidates])
        if length(results) >= k && distances[current] > distances[results[end]]
            break
        end
        
        push!(results, current)
        delete!(candidates, current)
        
        # 현재 노드의 이웃들 확인
        if layer < length(index.nodes[current].neighbors)
            for neighbor in index.nodes[current].neighbors[layer+1]
                if neighbor ∉ results
                    dist = euclidean_distance(query, index.nodes[neighbor].vector)
                    distances[neighbor] = dist
                    push!(candidates, neighbor)
                end
            end
        end
    end
    
    return results[1:min(k, length(results))]
end

"""
새로운 포인트를 
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 38: Write a Julia function to implement approximate nearest neighbor search in vector DB. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 근사 최근접 이웃 검색을 위한 벡터 데이터베이스 구현
# LSH(Locality Sensitive Hashing)를 사용한 방법

using LinearAlgebra

"""
벡터 데이터베이스를 위한 LSH 구조체
- vectors: 저장된 벡터들
- hash_tables: LSH 해시 테이블들
- proj_matrices: 랜덤 프로젝션 행렬들
- bucket_width: 해시 버킷 크기
"""
struct LSHDB
    vectors::Vector{Vector{Float64}}
    hash_tables::Vector{Dict{Vector{Int}, Vector{Int}}} 
    proj_matrices::Vector{Matrix{Float64}}
    bucket_width::Float64
end

"""
LSH 데이터베이스 초기화 함수
- dim: 벡터의 차원
- num_tables: 해시 테이블 개수
- num_projections: 프로젝션 개수
- w: 버킷 크기
"""
function init_lshdb(dim::Int, num_tables::Int=10, num_projections::Int=4, w::Float64=4.0)
    # 빈 벡터 데이터베이스 생성
    vectors = Vector{Vector{Float64}}()
    
    # 해시 테이블 초기화
    hash_tables = [Dict{Vector{Int}, Vector{Int}}() for _ in 1:num_tables]
    
    # 랜덤 프로젝션 행렬 생성
    proj_matrices = [randn(num_projections, dim) for _ in 1:num_tables]
    
    LSHDB(vectors, hash_tables, proj_matrices, w)
end

"""
벡터를 해시 값으로 변환하는 함수
- vec: 입력 벡터
- proj_matrix: 프로젝션 행렬
- w: 버킷 크기
"""
function hash_vector(vec::Vector{Float64}, proj_matrix::Matrix{Float64}, w::Float64)
    # 프로젝션 수행
    projections = proj_matrix * vec
    
    # 해시 값 계산
    hash_vals = floor.(Int, projections / w)
    return hash_vals
end

"""
벡터를 데이터베이스에 추가하는 함수
- db: LSH 데이터베이스
- vec: 추가할 벡터
"""
function insert_vector!(db::LSHDB, vec::Vector{Float64})
    # 벡터 저장
    push!(db.vectors, vec)
    vec_idx = length(db.vectors)
    
    # 각 해시 테이블에 벡터 추가
    for (table_idx, (proj_matrix, hash_table)) in enumerate(zip(db.proj_matrices, db.hash_tables))
        hash_val = hash_vector(vec, proj_matrix, db.bucket_width)
        
        if !haskey(hash_table, hash_val)
            hash_table[hash_val] = Int[]
        end
        push!(hash_table[hash_val], vec_idx)
    end
end

"""
쿼리 벡터의 근사 최근접 이웃을 검색하는 함수
- db: LSH 데이터베이스
- query: 쿼리 벡터
- k: 찾을 이웃 개수
"""
function query_ann(db::LSHDB, query::Vector{Float64}, k::Int=1)
    candidates = Set{Int}()
    
    # 각 해시 테이블에서 후보 검색
    for (proj_matrix, hash_table) in zip(db.proj_matrices, db.hash_tables)
        hash_val
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 39: Write a Julia function to batch insert embeddings into vector database efficiently. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 벡터 데이터베이스에 임베딩을 배치 방식으로 효율적으로 삽입하는 Julia 함수입니다:

```julia
using LinearAlgebra
using DataStructures

"""
벡터 데이터베이스 구조체
fields:
- vectors: 실제 임베딩 벡터들을 저장하는 매트릭스
- metadata: 각 벡터에 대한 메타데이터를 저장하는 딕셔너리
- index: 빠른 검색을 위한 인덱스 구조
"""
mutable struct VectorDB
    vectors::Matrix{Float64}
    metadata::Dict{Int, Dict{String, Any}}
    index::Dict{Int, Vector{Float64}}
end

"""
벡터 데이터베이스 초기화 함수
params:
- dim: 벡터의 차원
"""
function init_vector_db(dim::Int)
    return VectorDB(
        Matrix{Float64}(undef, dim, 0),
        Dict{Int, Dict{String, Any}}(),
        Dict{Int, Vector{Float64}}()
    )
end

"""
배치 삽입 함수
params:
- db: 벡터 데이터베이스 인스턴스
- embeddings: 삽입할 임베딩 벡터들의 매트릭스 (각 열이 하나의 벡터)
- metadata: 각 벡터에 대한 메타데이터 배열
returns:
- 삽입된 벡터들의 ID 배열
"""
function batch_insert!(db::VectorDB, embeddings::Matrix{Float64}, metadata::Vector{Dict{String, Any}})
    # 입력 검증
    if size(embeddings, 2) != length(metadata)
        throw(ArgumentError("임베딩 개수와 메타데이터 개수가 일치하지 않습니다"))
    end
    
    # 현재 데이터베이스의 크기 확인
    current_size = size(db.vectors, 2)
    num_new_vectors = size(embeddings, 2)
    
    # 새로운 벡터들을 위한 공간 할당
    new_vectors = hcat(db.vectors, embeddings)
    
    # 새로운 ID 생성 및 메타데이터 저장
    new_ids = Vector{Int}(undef, num_new_vectors)
    for i in 1:num_new_vectors
        new_id = current_size + i
        new_ids[i] = new_id
        
        # 메타데이터 저장
        db.metadata[new_id] = metadata[i]
        
        # 인덱스 업데이트
        db.index[new_id] = embeddings[:, i]
    end
    
    # 데이터베이스 업데이트
    db.vectors = new_vectors
    
    return new_ids
end

"""
벡터 정규화 함수
params:
- vectors: 정규화할 벡터들의 매트릭스
returns:
- 정규화된 벡터들의 매트릭스
"""
function normalize_vectors!(vectors::Matrix{Float64})
    for i in 1:size(vectors, 2)
        vectors[:, i] = vectors[:, i] ./ norm(vectors[:, i])
    end
    return vectors
end

"""
사용 예시:
```julia
# 데이터베이스 초기화 (128차원 벡터)
db = init_vector_db(128)

# 테스트 데이터 생성
test_embeddings = rand(128, 1000)  # 1000개의 128차원 벡터
test_metadata
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 40: Write a Julia function to implement vector similarity search with filtering. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
"""
벡터 유사도 검색을 구현한 모듈입니다.
필터링 기능이 포함되어 있습니다.
"""
module VectorSearch

using LinearAlgebra

"""
벡터 데이터베이스를 저장하는 구조체
- vectors: 벡터 데이터를 저장하는 행렬
- metadata: 각 벡터에 대한 메타데이터 
"""
struct VectorDB
    vectors::Matrix{Float64}  # 벡터 데이터 행렬
    metadata::Vector{Dict}    # 메타데이터 배열
end

"""
코사인 유사도를 계산하는 함수
두 벡터 간의 코사인 유사도를 반환합니다.
"""
function cosine_similarity(v1::Vector{Float64}, v2::Vector{Float64})
    return dot(v1, v2) / (norm(v1) * norm(v2))
end

"""
유클리디안 거리를 계산하는 함수
두 벡터 간의 유클리디안 거리를 반환합니다.
"""
function euclidean_distance(v1::Vector{Float64}, v2::Vector{Float64})
    return norm(v1 - v2)
end

"""
벡터 유사도 검색을 수행하는 주요 함수

매개변수:
- db: 벡터 데이터베이스
- query: 검색할 쿼리 벡터
- k: 반환할 상위 결과 개수
- filter_fn: 필터링 함수 (선택적)
- metric: 사용할 거리/유사도 측정 방식 ("cosine" 또는 "euclidean")

반환값:
- indices: 가장 유사한 벡터들의 인덱스
- scores: 각 벡터의 유사도/거리 점수
"""
function search(
    db::VectorDB,
    query::Vector{Float64},
    k::Int;
    filter_fn::Function=(x)->true,
    metric::String="cosine"
)
    # 거리/유사도 계산 함수 선택
    similarity_fn = metric == "cosine" ? cosine_similarity : euclidean_distance
    
    # 결과를 저장할 배열 초기화
    scores = Float64[]
    indices = Int[]
    
    # 모든 벡터에 대해 유사도 계산 및 필터링
    for i in 1:size(db.vectors, 2)
        # 메타데이터 필터링 검사
        if !filter_fn(db.metadata[i])
            continue
        end
        
        # 현재 벡터 추출
        current_vector = db.vectors[:, i]
        
        # 유사도/거리 계산
        score = similarity_fn(query, current_vector)
        
        push!(scores, score)
        push!(indices, i)
    end
    
    # 결과 정렬
    # 코사인 유사도는 높을수록, 유클리디안 거리는 낮을수록 좋음
    if metric == "cosine"
        sorted_idx = sortperm(scores, rev=true)[1:min(k, length(scores))]
    else
        sorted_idx = sortperm(scores)[1:min(k, length(scores))]
    end
    
    return indices[sorted_idx], scores[sorted_idx]
end

end # module

# 사용 예시:
"""
# 데이터베이스 생성 예시
vectors = rand(128, 1000)  # 128차원 벡터 1000개
metadata = [Dict("category"
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 41: Write a Julia function to manage vector database index updates and rebuilding. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 벡터 데이터베이스 인덱스 관리를 위한 모듈
module VectorIndexManager

using LinearAlgebra
using Statistics

# 인덱스 구조체 정의
"""
벡터 인덱스 구조체
- vectors: 벡터 데이터를 저장하는 행렬
- metadata: 각 벡터의 메타데이터
- is_dirty: 인덱스가 업데이트가 필요한지 표시
"""
mutable struct VectorIndex
    vectors::Matrix{Float64}
    metadata::Vector{Dict{String,Any}} 
    is_dirty::Bool
end

"""
새로운 벡터 인덱스를 생성하는 함수
dim: 벡터의 차원
"""
function create_index(dim::Int)
    VectorIndex(
        Matrix{Float64}(undef, 0, dim),
        Vector{Dict{String,Any}}(),
        false
    )
end

"""
인덱스에 새로운 벡터를 추가하는 함수
index: 벡터 인덱스
vector: 추가할 벡터
metadata: 벡터의 메타데이터
"""
function add_vector!(index::VectorIndex, vector::Vector{Float64}, metadata::Dict{String,Any})
    # 벡터 차원 확인
    if length(vector) != size(index.vectors, 2)
        throw(ArgumentError("벡터 차원이 일치하지 않습니다"))
    end
    
    # 벡터와 메타데이터 추가
    index.vectors = vcat(index.vectors, vector')
    push!(index.metadata, metadata)
    index.is_dirty = true
end

"""
인덱스에서 벡터를 삭제하는 함수
index: 벡터 인덱스
id: 삭제할 벡터의 ID
"""
function remove_vector!(index::VectorIndex, id::Int)
    if id > size(index.vectors, 1)
        throw(ArgumentError("존재하지 않는 ID입니다"))
    end
    
    # 벡터와 메타데이터 삭제
    index.vectors = index.vectors[1:end .!= id, :]
    deleteat!(index.metadata, id)
    index.is_dirty = true
end

"""
인덱스를 재구축하는 함수
- 벡터 정규화
- 기타 최적화 작업 수행
"""
function rebuild_index!(index::VectorIndex)
    # 비어있는 인덱스 확인
    if size(index.vectors, 1) == 0
        return
    end
    
    # 벡터 정규화
    normalized_vectors = mapslices(v -> v ./ norm(v), index.vectors, dims=2)
    index.vectors = normalized_vectors
    
    # 인덱스 상태 업데이트
    index.is_dirty = false
end

"""
가장 유사한 벡터를 검색하는 함수
index: 벡터 인덱스
query: 검색할 쿼리 벡터
k: 반환할 결과 개수
"""
function search_similar(index::VectorIndex, query::Vector{Float64}, k::Int)
    if index.is_dirty
        rebuild_index!()
    end
    
    # 쿼리 벡터 정규화
    normalized_query = query ./ norm(query)
    
    # 코사인 유사도 계산
    similarities = index.vectors * normalized_query
    
    # 상위 k개 결과 반환
    top_k_indices = partialsortperm(similarities, 1:k, rev=true)
    return [(i, index
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 42: Write a Julia function to implement vector DB backup and restore procedures. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function implementing vector DB backup and restore procedures with Korean comments:

```julia
using JSON
using FileIO
using Statistics

"""
벡터 데이터베이스의 백업 및 복원 기능을 제공하는 모듈
"""
module VectorDBManager

# 기본 데이터 구조
mutable struct VectorDB
    vectors::Dict{String, Vector{Float64}}
    metadata::Dict{String, Any}
    timestamp::Float64
end

"""
벡터 데이터베이스를 파일로 백업하는 함수
params:
    - db: 백업할 벡터 데이터베이스
    - filepath: 백업 파일 경로
"""
function backup_db(db::VectorDB, filepath::String)
    try
        # 백업 데이터 준비
        backup_data = Dict(
            "vectors" => db.vectors,
            "metadata" => db.metadata,
            "timestamp" => time()
        )
        
        # JSON 형식으로 저장
        open(filepath, "w") do file
            JSON.print(file, backup_data)
        end
        
        println("✓ 백업이 성공적으로 완료되었습니다: $filepath")
        return true
    catch e
        println("⚠ 백업 중 오류가 발생했습니다: $e")
        return false
    end
end

"""
백업 파일에서 벡터 데이터베이스를 복원하는 함수
params:
    - filepath: 복원할 백업 파일 경로
returns:
    - 복원된 VectorDB 인스턴스
"""
function restore_db(filepath::String)
    try
        # 파일 존재 여부 확인
        if !isfile(filepath)
            throw(ErrorException("백업 파일을 찾을 수 없습니다."))
        end

        # JSON 파일 읽기
        backup_data = JSON.parsefile(filepath)
        
        # 데이터 유효성 검사
        if !haskey(backup_data, "vectors") || !haskey(backup_data, "metadata")
            throw(ErrorException("잘못된 백업 파일 형식입니다."))
        end

        # VectorDB 인스턴스 생성
        restored_db = VectorDB(
            Dict{String, Vector{Float64}}(backup_data["vectors"]),
            backup_data["metadata"],
            backup_data["timestamp"]
        )

        println("✓ 데이터베이스가 성공적으로 복원되었습니다.")
        return restored_db
    catch e
        println("⚠ 복원 중 오류가 발생했습니다: $e")
        return nothing
    end
end

"""
벡터 데이터베이스의 상태를 검증하는 함수
params:
    - db: 검증할 벡터 데이터베이스
returns:
    - 검증 결과 (boolean)
"""
function validate_db(db::VectorDB)
    try
        # 기본 구조 검증
        if isempty(db.vectors)
            println("⚠ 경고: 벡터 데이터가 비어 있습니다.")
            return false
        end

        # 벡터 차원 일관성 검사
        dims = unique([length(v) for v in values(db.vectors)])
        if length(dims) > 1
            println("⚠ 오류: 벡터 차원이 일관되지 않습니다.")
            return false
        end

        # 메타데이터 검증
        if !haskey(db.metadata, "version")
            println("⚠ 경고: 버전 정보가 없습니다.")
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 43: Write a Julia function to optimize vector database query performance. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function to optimize vector database query performance with Korean comments:

```julia
# 벡터 데이터베이스 쿼리 최적화를 위한 모듈
module VectorDBOptimizer

using LinearAlgebra
using NearestNeighbors

"""
벡터 검색 성능 최적화를 위한 주요 구조체
- vectors: 데이터베이스에 저장된 벡터들
- index: 근접 이웃 검색을 위한 인덱스
- metadata: 각 벡터와 관련된 메타데이터
"""
mutable struct VectorDB
    vectors::Matrix{Float64}
    index::Any
    metadata::Vector{Dict}
end

"""
새로운 벡터 데이터베이스 인스턴스 생성
- dimension: 벡터의 차원
"""
function create_vector_db(dimension::Int)
    return VectorDB(
        Matrix{Float64}(undef, dimension, 0),
        nothing,
        Vector{Dict}()
    )
end

"""
데이터베이스에 새로운 벡터 추가
- db: 벡터 데이터베이스 인스턴스
- vector: 추가할 벡터
- metadata: 벡터와 관련된 메타데이터
"""
function add_vector!(db::VectorDB, vector::Vector{Float64}, metadata::Dict)
    # 벡터를 데이터베이스에 추가
    db.vectors = hcat(db.vectors, vector)
    push!(db.metadata, metadata)
    
    # 인덱스 재구축
    rebuild_index!(db)
end

"""
검색 성능 향상을 위한 인덱스 재구축
- db: 벡터 데이터베이스 인스턴스
"""
function rebuild_index!(db::VectorDB)
    # KD-트리 인덱스 구축
    if size(db.vectors, 2) > 0
        db.index = KDTree(db.vectors)
    end
end

"""
최근접 이웃 벡터 검색
- db: 벡터 데이터베이스 인스턴스
- query: 검색할 쿼리 벡터
- k: 반환할 최근접 이웃의 수
"""
function search_nearest(db::VectorDB, query::Vector{Float64}, k::Int)
    if isnothing(db.index) || size(db.vectors, 2) == 0
        return [], [], Float64[]
    end

    # KD-트리를 사용한 효율적인 검색 수행
    k = min(k, size(db.vectors, 2))
    distances, indices = knn(db.index, query, k)
    
    # 결과 벡터와 메타데이터 수집
    result_vectors = [db.vectors[:, i] for i in indices]
    result_metadata = [db.metadata[i] for i in indices]
    
    return result_vectors, result_metadata, distances
end

"""
벡터 간 코사인 유사도 계산
"""
function cosine_similarity(v1::Vector{Float64}, v2::Vector{Float64})
    return dot(v1, v2) / (norm(v1) * norm(v2))
end

"""
벡터 정규화
"""
function normalize_vector!(vector::Vector{Float64})
    vector ./= norm(vector)
end

end # module

# 사용 예시
using .VectorDBOptimizer

# 테스트 코드
function test_vector_db()
    # 3차원 벡터 데이터베이스 생성
    db = create_vector_db(3)
    
    # 테스트 벡터 추가
    
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 44: Write a Julia function to implement model versioning and registry management. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 Julia에서 모델 버전 관리와 레지스트리 관리를 위한 함수들입니다:

```julia
using Dates
using JSON

"""
모델 버전 및 레지스트리 관리를 위한 구조체
"""
struct ModelVersion
    model_id::String
    version::VersionNumber
    created_at::DateTime
    metadata::Dict{String, Any}
end

"""
모델 레지스트리를 관리하는 주요 구조체
"""
mutable struct ModelRegistry
    models::Dict{String, Vector{ModelVersion}}
    registry_path::String
end

"""
새로운 모델 레지스트리를 초기화하는 함수
"""
function init_registry(path::String)
    if !isdir(path)
        mkdir(path)
    end
    return ModelRegistry(Dict{String, Vector{ModelVersion}}(), path)
end

"""
새로운 모델 버전을 등록하는 함수
params:
- registry: ModelRegistry 객체
- model_id: 모델 식별자
- version: 버전 번호
- metadata: 모델 메타데이터
"""
function register_model_version!(
    registry::ModelRegistry,
    model_id::String,
    version::VersionNumber,
    metadata::Dict{String, Any}
)
    model_version = ModelVersion(
        model_id,
        version,
        now(),
        metadata
    )

    if !haskey(registry.models, model_id)
        registry.models[model_id] = ModelVersion[]
    end

    push!(registry.models[model_id], model_version)
    
    # 레지스트리를 파일로 저장
    save_registry(registry)
    
    return model_version
end

"""
레지스트리를 파일로 저장하는 함수
"""
function save_registry(registry::ModelRegistry)
    registry_data = Dict{String, Any}()
    
    for (model_id, versions) in registry.models
        registry_data[model_id] = [
            Dict(
                "version" => string(v.version),
                "created_at" => string(v.created_at),
                "metadata" => v.metadata
            ) for v in versions
        ]
    end
    
    open(joinpath(registry.registry_path, "registry.json"), "w") do f
        JSON.print(f, registry_data, 4)
    end
end

"""
특정 모델의 최신 버전을 가져오는 함수
"""
function get_latest_version(registry::ModelRegistry, model_id::String)
    if !haskey(registry.models, model_id)
        error("모델 ID를 찾을 수 없습니다: $model_id")
    end
    
    versions = registry.models[model_id]
    return maximum(versions, by=v -> v.version)
end

"""
특정 모델의 특정 버전을 가져오는 함수
"""
function get_model_version(
    registry::ModelRegistry,
    model_id::String,
    version::VersionNumber
)
    if !haskey(registry.models, model_id)
        error("모델 ID를 찾을 수 없습니다: $model_id")
    end
    
    version_match = filter(v -> v.version == version, registry.models[model_id])
    
    if isempty(version_match)
        error("버전을 찾을 수 없습니다: $version")
    end
    
    return first(version_match)
end

"""
사용 예시
"""
function example_usage()
    # 레지스트리 초기화
    registry = init_registry("model_registry")
    
    # 새 모델 버전 등록
    metadata = Dict(
        "accuracy" => 0.95,
        "framework"
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 45: Write a Julia function to create experiment tracking for LLM training runs. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
using Dates
using JSON

"""
LLM 실험 추적을 위한 구조체
fields:
- experiment_id: 실험 고유 식별자
- model_name: 모델 이름
- hyperparameters: 하이퍼파라미터 설정
- metrics: 학습 중 측정된 메트릭
- timestamps: 시작/종료 시간
- status: 실험 상태
"""
mutable struct ExperimentTracker
    experiment_id::String
    model_name::String
    hyperparameters::Dict
    metrics::Dict
    timestamps::Dict
    status::String
end

"""
새로운 실험 트래커를 생성하는 함수

Parameters:
- model_name: 모델 이름
- hyperparameters: 하이퍼파라미터 설정값

Returns:
- ExperimentTracker 객체
"""
function create_experiment(model_name::String, hyperparameters::Dict)
    experiment_id = string(hash(string(now())), base=16)
    
    tracker = ExperimentTracker(
        experiment_id,
        model_name,
        hyperparameters,
        Dict(),
        Dict("start_time" => now()),
        "running"
    )
    
    # 실험 로그 파일 생성
    save_experiment(tracker)
    
    return tracker
end

"""
메트릭을 기록하는 함수

Parameters:
- tracker: ExperimentTracker 객체
- metric_name: 메트릭 이름
- value: 메트릭 값
- step: 현재 학습 스텝
"""
function log_metric!(tracker::ExperimentTracker, metric_name::String, value::Number, step::Int)
    if !haskey(tracker.metrics, metric_name)
        tracker.metrics[metric_name] = []
    end
    
    push!(tracker.metrics[metric_name], Dict(
        "step" => step,
        "value" => value,
        "timestamp" => now()
    ))
    
    # 실험 로그 업데이트
    save_experiment(tracker)
end

"""
실험을 종료하는 함수

Parameters:
- tracker: ExperimentTracker 객체
- status: 종료 상태 ("completed" 또는 "failed")
"""
function end_experiment!(tracker::ExperimentTracker, status::String)
    tracker.timestamps["end_time"] = now()
    tracker.status = status
    save_experiment(tracker)
end

"""
실험 데이터를 JSON 파일로 저장하는 함수

Parameters:
- tracker: ExperimentTracker 객체
"""
function save_experiment(tracker::ExperimentTracker)
    experiment_dir = "experiments"
    mkpath(experiment_dir)
    
    filename = joinpath(experiment_dir, "$(tracker.experiment_id).json")
    
    open(filename, "w") do f
        JSON.print(f, Dict(
            "experiment_id" => tracker.experiment_id,
            "model_name" => tracker.model_name,
            "hyperparameters" => tracker.hyperparameters,
            "metrics" => tracker.metrics,
            "timestamps" => tracker.timestamps,
            "status" => tracker.status
        ), 4)
    end
end

# 사용 예시
"""
실험 트래킹 사용 예시
"""
function example_usage()
    # 실험 생성
    hyperparams = Dict(
        "learning_rate" => 0.001,
        "batch_size" => 32,
        "epochs" => 10
    )
    
    tracker = create_experiment("gpt2-small", hyperparams)
    
    # 메트릭 기록
    for epoch in 1:5
        log_metric!(tracker, "loss", rand(), epoch)
        log_metric!(tracker, "accuracy", ran
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 46: Write a Julia function to implement continuous integration for LLM model updates. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# LLM 모델 업데이트를 위한 지속적 통합(CI) 구현
# 주요 기능:
# - 모델 성능 테스트
# - 자동 배포
# - 알림 발송
# - 로깅

using Logging
using HTTP
using JSON
using Dates

"""
LLM 모델 CI 파이프라인의 설정을 저장하는 구조체
"""
struct CIConfig
    model_path::String # 모델 파일 경로
    test_dataset::String # 테스트 데이터셋 경로
    performance_threshold::Float64 # 성능 임계값
    notify_url::String # 알림 웹훅 URL
end

"""
모델 성능 테스트 결과를 저장하는 구조체
"""
struct TestResult
    accuracy::Float64
    latency::Float64
    passed::Bool
    timestamp::DateTime
end

"""
모델을 테스트하고 결과를 반환하는 함수
"""
function test_model(config::CIConfig)
    # 실제 구현에서는 모델을 로드하고 테스트 데이터셋으로 평가
    @info "모델 테스트 시작"
    
    # 예시 테스트 결과
    accuracy = rand() * 100
    latency = rand() * 1000
    passed = accuracy > config.performance_threshold
    
    return TestResult(
        accuracy,
        latency,
        passed,
        now()
    )
end

"""
테스트 결과에 따라 모델을 배포하는 함수
"""
function deploy_model(config::CIConfig, test_result::TestResult)
    if test_result.passed
        @info "모델 배포 시작"
        # 실제 구현에서는 모델 파일을 프로덕션 환경으로 복사
        return true
    else
        @warn "성능 임계값 미달로 배포 중단"
        return false
    end
end

"""
테스트 결과를 웹훅으로 알림 발송하는 함수
"""
function send_notification(config::CIConfig, test_result::TestResult, deployed::Bool)
    message = Dict(
        "accuracy" => test_result.accuracy,
        "latency" => test_result.latency,
        "passed" => test_result.passed,
        "deployed" => deployed,
        "timestamp" => string(test_result.timestamp)
    )
    
    try
        HTTP.post(
            config.notify_url,
            ["Content-Type" => "application/json"],
            JSON.json(message)
        )
        @info "알림 발송 완료"
    catch e
        @error "알림 발송 실패" exception=e
    end
end

"""
전체 CI 파이프라인을 실행하는 메인 함수
"""
function run_ci_pipeline(config::CIConfig)
    @info "CI 파이프라인 시작"
    
    # 로그 파일 설정
    logger = SimpleLogger(open("ci_log.txt", "a"))
    global_logger(logger)
    
    try
        # 모델 테스트 실행
        test_result = test_model(config)
        
        # 테스트 통과시 배포
        deployed = deploy_model(config, test_result)
        
        # 결과 알림 발송
        send_notification(config, test_result, deployed)
        
        @info "CI 파이프라인 완료" result=test_result deployed=deployed
        
    catch e
        @error "CI 파이프라인 실패" exception=e
    finally
        close(logger.stream)
    end
end
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 47: Write a Julia function to monitor model drift and performance degradation. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function to monitor model drift and performance degradation with Korean comments:

```julia
# 모델 드리프트와 성능 저하를 모니터링하기 위한 모듈
module ModelDriftMonitor

using Statistics
using Dates
using DataFrames

"""
성능 메트릭스를 저장하기 위한 구조체
- metric_name: 메트릭의 이름
- values: 시간에 따른 메트릭 값들
- timestamps: 측정 시간
"""
mutable struct PerformanceMetric
    metric_name::String
    values::Vector{Float64}
    timestamps::Vector{DateTime}
end

"""
모델 드리프트를 모니터링하는 주요 함수
- current_predictions: 현재 모델의 예측값
- current_labels: 실제 레이블
- reference_predictions: 기준이 되는 예측값
- reference_labels: 기준이 되는 레이블
- threshold: 경고를 발생시키는 임계값
"""
function monitor_drift(
    current_predictions::Vector{Float64},
    current_labels::Vector{Float64},
    reference_predictions::Vector{Float64},
    reference_labels::Vector{Float64},
    threshold::Float64=0.1
)
    # 현재 성능 계산
    current_metrics = calculate_metrics(current_predictions, current_labels)
    
    # 기준 성능 계산
    reference_metrics = calculate_metrics(reference_predictions, reference_labels)
    
    # 드리프트 감지
    drift_detected = false
    drift_metrics = Dict{String, Float64}()
    
    for metric in keys(current_metrics)
        # 성능 차이 계산
        diff = abs(current_metrics[metric] - reference_metrics[metric])
        drift_metrics[metric] = diff
        
        # 임계값을 넘으면 드리프트 감지
        if diff > threshold
            drift_detected = true
        end
    end
    
    return (
        drift_detected=drift_detected,
        drift_metrics=drift_metrics,
        current_metrics=current_metrics,
        reference_metrics=reference_metrics
    )
end

"""
주요 성능 메트릭을 계산하는 도우미 함수
- predictions: 모델의 예측값
- labels: 실제 레이블
"""
function calculate_metrics(predictions::Vector{Float64}, labels::Vector{Float64})
    # MSE (평균 제곱 오차) 계산
    mse = mean((predictions .- labels).^2)
    
    # MAE (평균 절대 오차) 계산
    mae = mean(abs.(predictions .- labels))
    
    # R² (결정 계수) 계산
    ss_tot = sum((labels .- mean(labels)).^2)
    ss_res = sum((labels .- predictions).^2)
    r2 = 1 - (ss_res / ss_tot)
    
    return Dict(
        "MSE" => mse,
        "MAE" => mae,
        "R2" => r2
    )
end

"""
시계열 데이터에서 트렌드를 분석하는 함수
- metric: PerformanceMetric 객체
- window_size: 이동 평균을 계산할 윈도우 크기
"""
function analyze_trend(metric::PerformanceMetric, window_size::Int=5)
    # 이동 평균 계산
    moving_avg = zeros(length(metric.values))
    for i in window_size:length(metric.values)
        moving_avg[i] = mean(metric.values[i-window_size+1:i])
    end
    
    # 추세 계산 (양수: 상승, 음수: 하락)
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 48: Write a Julia function to implement automated model deployment pipelines. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 모델 배포 파이프라인을 위한 모듈
module ModelDeployment

using AWS # AWS 서비스 사용
using MLJ # 머신러닝 모델링
using DataFrames # 데이터 처리
using Dates # 날짜/시간 처리

"""
모델 배포 설정을 위한 구조체
"""
struct DeploymentConfig
    model_path::String # 모델 파일 경로
    aws_region::String # AWS 리전
    endpoint_name::String # 엔드포인트 이름
    instance_type::String # 인스턴스 타입
end

"""
모델 검증을 수행하는 함수
model: 배포할 모델
data: 검증용 데이터
"""
function validate_model(model, data)
    try
        # 모델 성능 메트릭 계산
        predictions = predict(model, data)
        accuracy = score(predictions, data.target)
        
        if accuracy < 0.8
            @warn "모델 성능이 기준치보다 낮습니다 (정확도: $accuracy)"
            return false
        end
        return true
    catch e
        @error "모델 검증 중 오류 발생: $e"
        return false
    end
end

"""
AWS SageMaker에 모델을 배포하는 함수
config: 배포 설정
"""
function deploy_to_sagemaker(config::DeploymentConfig)
    try
        # AWS SageMaker 클라이언트 생성
        sagemaker = AWS.SageMaker(config.aws_region)
        
        # 모델 아티팩트 S3 업로드
        model_artifact = upload_to_s3(config.model_path)
        
        # SageMaker 모델 생성
        create_model_response = create_model(sagemaker, 
                                          config.endpoint_name,
                                          model_artifact,
                                          config.instance_type)
        
        # 엔드포인트 설정 생성
        endpoint_config = create_endpoint_config(sagemaker, config)
        
        # 엔드포인트 배포
        create_endpoint(sagemaker, config.endpoint_name, endpoint_config)
        
        @info "모델이 성공적으로 배포되었습니다"
        return true
        
    catch e
        @error "모델 배포 중 오류 발생: $e"
        return false
    end
end

"""
배포 모니터링을 위한 함수
endpoint_name: 모니터링할 엔드포인트 이름
"""
function monitor_deployment(endpoint_name::String)
    try
        # 엔드포인트 상태 확인
        status = get_endpoint_status(endpoint_name)
        
        # 성능 메트릭 수집
        metrics = collect_metrics(endpoint_name)
        
        # 로그 기록
        log_deployment_metrics(endpoint_name, metrics)
        
        return status, metrics
    catch e
        @error "모니터링 중 오류 발생: $e"
        return nothing, nothing
    end
end

"""
전체 배포 파이프라인을 실행하는 메인 함수
"""
function run_deployment_pipeline(model, validation_data, config::DeploymentConfig)
    # 타임스탬프 기록
    deployment_start = now()
    
    @info "배포 파이프라인 시작: $(deployment_start)"
    
    # 1. 모델 검증
    if !validate_model(model, validation_data)
        @error "모델 검증 실패"
        return false
    end
    
    # 2. 모델 배포
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 49: Write a Julia function to create feature flags for gradual model rollouts. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 Julia로 작성된 점진적 모델 롤아웃을 위한 피처 플래그 기능입니다:

```julia
using Random
using Dates

"""
피처 플래그 구성을 저장하는 구조체
- name: 피처 플래그 이름
- enabled: 활성화 여부
- rollout_percentage: 롤아웃 비율 (0-100)
- start_date: 롤아웃 시작 일자
- end_date: 롤아웃 종료 일자
"""
mutable struct FeatureFlag
    name::String
    enabled::Bool
    rollout_percentage::Float64
    start_date::DateTime
    end_date::DateTime
end

"""
피처 플래그들을 관리하는 매니저 구조체
"""
mutable struct FeatureFlagManager
    flags::Dict{String, FeatureFlag}
end

"""
새로운 피처 플래그 매니저 인스턴스를 생성합니다
"""
function create_feature_flag_manager()
    FeatureFlagManager(Dict{String, FeatureFlag}())
end

"""
새로운 피처 플래그를 생성하고 등록합니다
매개변수:
- manager: 피처 플래그 매니저
- name: 피처 이름
- rollout_percentage: 롤아웃 비율
- start_date: 시작 일자
- end_date: 종료 일자
"""
function create_feature_flag(
    manager::FeatureFlagManager,
    name::String,
    rollout_percentage::Float64,
    start_date::DateTime,
    end_date::DateTime
)
    if rollout_percentage < 0 || rollout_percentage > 100
        throw(ArgumentError("롤아웃 비율은 0에서 100 사이여야 합니다"))
    end

    flag = FeatureFlag(name, false, rollout_percentage, start_date, end_date)
    manager.flags[name] = flag
    return flag
end

"""
특정 사용자/세션에 대해 피처 플래그가 활성화되어야 하는지 확인합니다
매개변수:
- manager: 피처 플래그 매니저
- flag_name: 피처 플래그 이름
- user_id: 사용자 식별자
"""
function is_feature_enabled(manager::FeatureFlagManager, flag_name::String, user_id::String)
    if !haskey(manager.flags, flag_name)
        return false
    end

    flag = manager.flags[flag_name]
    current_time = now()

    # 날짜 범위 확인
    if current_time < flag.start_date || current_time > flag.end_date
        return false
    end

    # 기본 활성화 상태 확인
    if !flag.enabled
        return false
    end

    # 사용자 ID를 기반으로 한 결정적 해시 생성
    hash_value = hash(user_id * flag_name)
    normalized_hash = abs(hash_value) % 100

    # 롤아웃 비율에 따른 활성화 여부 결정
    return normalized_hash < flag.rollout_percentage
end

"""
피처 플래그의 활성화 상태를 변경합니다
"""
function toggle_feature_flag(manager::FeatureFlagManager, flag_name::String, enabled::Bool)
    if haskey(manager.flags, flag_name)
        manager.flags[flag_name].enabled = enabled
        return true
    end
    return false
end

```

사용 예시:

```julia
# 피처 플래그 매니저 생성
manager = create_
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 50: Write a Julia function to implement model rollback mechanisms. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 Julia에서 모델 롤백 메커니즘을 구현하는 함수들입니다:

```julia
# 모델의 상태를 저장하기 위한 구조체
mutable struct ModelCheckpoint
    parameters::Dict{String, Any}  # 모델 파라미터
    timestamp::Float64            # 저장 시점
    version::String              # 모델 버전
    metadata::Dict{String, Any}  # 추가 메타데이터
end

"""
현재 모델의 상태를 저장하는 함수
model: 저장할 모델
version: 모델 버전
metadata: 추가 메타데이터
"""
function save_checkpoint(model, version::String, metadata::Dict{String, Any} = Dict())
    try
        # 모델 파라미터 추출
        parameters = Dict{String, Any}()
        for (name, param) in pairs(model)
            parameters[string(name)] = copy(param)
        end

        # 체크포인트 생성
        checkpoint = ModelCheckpoint(
            parameters,
            time(),
            version,
            metadata
        )

        # 체크포인트를 파일로 저장
        filename = "checkpoint_$(version)_$(Int(floor(checkpoint.timestamp))).jld2"
        save(filename, "checkpoint", checkpoint)
        
        println("체크포인트가 저장되었습니다: $filename")
        return checkpoint
    catch e
        println("체크포인트 저장 중 오류 발생: ", e)
        return nothing
    end
end

"""
저장된 체크포인트로부터 모델을 복원하는 함수
model: 복원할 모델
checkpoint_path: 체크포인트 파일 경로
"""
function rollback_model!(model, checkpoint_path::String)
    try
        # 체크포인트 파일 로드
        checkpoint = load(checkpoint_path, "checkpoint")

        # 모델 파라미터 복원
        for (name, param) in checkpoint.parameters
            if haskey(model, Symbol(name))
                model[Symbol(name)] .= param
            end
        end

        println("모델이 성공적으로 복원되었습니다. 버전: $(checkpoint.version)")
        return true
    catch e
        println("모델 복원 중 오류 발생: ", e)
        return false
    end
end

"""
사용 가능한 체크포인트 목록을 반환하는 함수
directory: 체크포인트가 저장된 디렉토리
"""
function list_checkpoints(directory::String = ".")
    try
        # 체크포인트 파일 찾기
        checkpoints = filter(x -> startswith(x, "checkpoint_") && endswith(x, ".jld2"), 
                           readdir(directory))
        
        println("사용 가능한 체크포인트:")
        for (i, checkpoint) in enumerate(checkpoints)
            println("$i. $checkpoint")
        end
        
        return checkpoints
    catch e
        println("체크포인트 목록 조회 중 오류 발생: ", e)
        return String[]
    end
end

"""
가장 최근의 체크포인트를 찾는 함수
directory: 체크포인트가 저장된 디렉토리
"""
function get_latest_checkpoint(directory::String = ".")
    checkpoints = list_checkpoints(directory)
    if isempty(checkpoints)
        return nothing
    end
    
    # 타임스탬프를 기준으로 정렬하여 가장 최근 체크포인트 반환
    return sort(checkpoints, by=x -> parse(Int, split(split(x, "_")[3], ".")[1]))[
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 51: Write a Julia function to log training metrics and visualize learning curves. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
using Plots
using DataFrames
using CSV

"""
학습 메트릭을 저장하고 시각화하는 기능을 제공하는 구조체
fields:
- metrics: 각 에포크별 메트릭을 저장하는 Dict
- save_path: 메트릭을 저장할 파일 경로
"""
mutable struct TrainingLogger
    metrics::Dict{String, Vector{Float64}}
    save_path::String
    
    # 생성자
    TrainingLogger(save_path::String) = new(Dict{String, Vector{Float64}}(), save_path)
end

"""
한 에포크의 메트릭을 기록하는 함수

inputs:
- logger: TrainingLogger 객체
- epoch_metrics: 에포크 메트릭이 담긴 Dict
"""
function log_metrics!(logger::TrainingLogger, epoch_metrics::Dict{String,Float64})
    for (key, value) in epoch_metrics
        if !haskey(logger.metrics, key)
            logger.metrics[key] = Float64[]
        end
        push!(logger.metrics[key], value)
    end
end

"""
현재까지의 학습 곡선을 시각화하는 함수

inputs:
- logger: TrainingLogger 객체
- metrics_to_plot: 시각화할 메트릭 이름들의 배열
"""
function plot_learning_curves(logger::TrainingLogger, metrics_to_plot::Vector{String})
    p = plot(
        layout = (length(metrics_to_plot), 1),
        size = (800, 200 * length(metrics_to_plot))
    )
    
    # 각 메트릭별 서브플롯 생성
    for (i, metric) in enumerate(metrics_to_plot)
        if haskey(logger.metrics, metric)
            plot!(
                p[i],
                logger.metrics[metric],
                label = metric,
                xlabel = "에포크",
                ylabel = metric,
                title = "학습 곡선: $metric"
            )
        end
    end
    
    display(p)
end

"""
메트릭을 CSV 파일로 저장하는 함수

input:
- logger: TrainingLogger 객체
"""
function save_metrics(logger::TrainingLogger)
    df = DataFrame(logger.metrics)
    CSV.write(logger.save_path, df)
    println("메트릭이 $(logger.save_path)에 저장되었습니다.")
end

# 사용 예시
function example_usage()
    # 로거 초기화
    logger = TrainingLogger("training_metrics.csv")
    
    # 학습 루프 시뮬레이션
    for epoch in 1:10
        # 가상의 학습 메트릭
        epoch_metrics = Dict(
            "loss" => 1.0/epoch,
            "accuracy" => 0.5 + 0.05*epoch,
            "val_loss" => 1.2/epoch,
            "val_accuracy" => 0.45 + 0.05*epoch
        )
        
        # 메트릭 기록
        log_metrics!(logger, epoch_metrics)
        
        # 매 3 에포크마다 학습 곡선 표시
        if epoch % 3 == 0
            plot_learning_curves(logger, ["loss", "accuracy", "val_loss", "val_accuracy"])
        end
    end
    
    # 최종 메트릭 저장
    save_metrics(logger)
end
```

이 코드는 다음과 같은 주요 기능을 제공합니다:

1. `TrainingLogger` 구조체:
   - 학습 중 발생하는 다양한 메트릭을 저장
   - CSV 파일 저장 
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 52: Write a Julia function to implement distributed training coordination. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 분산 학습 조정을 위한 Julia 함수 구현입니다:

```julia
using Distributed
using ProgressMeter

"""
분산 학습 코디네이터 구조체
parameters:
    - num_workers: 작업자 노드 수
    - batch_size: 배치 크기
    - epochs: 전체 학습 에폭 수
    - model_state: 모델 상태 저장
"""
mutable struct DistributedTrainer
    num_workers::Int
    batch_size::Int
    epochs::Int
    model_state::Dict
end

"""
그래디언트 업데이트를 동기화하는 함수
parameters:
    - gradients: 각 작업자로부터 받은 그래디언트
returns:
    - 평균화된 그래디언트
"""
function synchronize_gradients(gradients)
    # 모든 작업자로부터 받은 그래디언트의 평균 계산
    mean_gradients = mean(gradients)
    return mean_gradients
end

"""
분산 학습을 실행하는 메인 함수
parameters:
    - trainer: DistributedTrainer 인스턴스
    - data: 학습 데이터
"""
function train_distributed!(trainer::DistributedTrainer, data)
    # 데이터를 작업자 수만큼 분할
    data_chunks = split_data(data, trainer.num_workers)
    
    @showprogress for epoch in 1:trainer.epochs
        # 각 작업자에게 데이터 청크 할당
        @sync begin
            for (worker_id, data_chunk) in enumerate(data_chunks)
                @async begin
                    # 작업자에게 학습 작업 전달
                    gradients = remotecall_fetch(
                        train_worker!,
                        worker_id + 1,  # 작업자 ID
                        data_chunk,
                        trainer.batch_size,
                        trainer.model_state
                    )
                    
                    # 그래디언트 동기화
                    synchronized_gradients = synchronize_gradients(gradients)
                    
                    # 모델 상태 업데이트
                    update_model_state!(trainer.model_state, synchronized_gradients)
                end
            end
        end
    end
end

"""
개별 작업자에서 실행되는 학습 함수
parameters:
    - data_chunk: 작업자에게 할당된 데이터
    - batch_size: 배치 크기
    - model_state: 현재 모델 상태
returns:
    - 계산된 그래디언트
"""
function train_worker!(data_chunk, batch_size, model_state)
    gradients = []
    
    # 배치 단위로 데이터 처리
    for batch in Iterators.partition(data_chunk, batch_size)
        # 포워드 패스
        predictions = forward_pass(model_state, batch)
        
        # 그래디언트 계산
        batch_gradients = backward_pass(predictions, batch)
        push!(gradients, batch_gradients)
    end
    
    return gradients
end

"""
데이터를 작업자 수만큼 분할하는 헬퍼 함수
parameters:
    - data: 전체 데이터셋
    - num_chunks: 분할할 청크 수
returns:
    - 분할된 데이터 청크들
"""
function split_data(data, num_chunks)
    chunk_size = div(length(data), num_chunks)
    return [data[i:min(i+chunk_size-1, length(data))] 
            for i in 1:chunk_size:length(
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 53: Write a Julia function to manage checkpoint saving and recovery. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 체크포인트 관리를 위한 모듈
module CheckpointManager

using JLD2  # 데이터 저장을 위한 패키지

export save_checkpoint, load_checkpoint, cleanup_old_checkpoints

"""
체크포인트 데이터를 저장하는 함수
- model: 저장할 모델
- optimizer: 현재 옵티마이저 상태 
- epoch: 현재 에포크
- loss: 현재 손실값
- filepath: 저장 경로
"""
function save_checkpoint(model, optimizer, epoch::Int, loss::Float64, filepath::String)
    try
        # 체크포인트 데이터를 딕셔너리로 구성
        checkpoint = Dict(
            "model_state" => model,
            "optimizer_state" => optimizer,
            "epoch" => epoch,
            "loss" => loss
        )
        
        # JLD2 형식으로 저장
        save(filepath, checkpoint)
        println("체크포인트가 성공적으로 저장됨: $filepath")
    catch e
        println("체크포인트 저장 중 오류 발생: $e")
    end
end

"""
체크포인트를 불러오는 함수
- filepath: 체크포인트 파일 경로
반환값: (model, optimizer, epoch, loss) 튜플 또는 실패시 nothing
"""
function load_checkpoint(filepath::String)
    try
        # 파일이 존재하는지 확인
        if !isfile(filepath)
            println("체크포인트 파일을 찾을 수 없음: $filepath")
            return nothing
        end
        
        # 체크포인트 로드
        checkpoint = load(filepath)
        
        return (
            checkpoint["model_state"],
            checkpoint["optimizer_state"],
            checkpoint["epoch"],
            checkpoint["loss"]
        )
    catch e
        println("체크포인트 로드 중 오류 발생: $e")
        return nothing
    end
end

"""
오래된 체크포인트 파일들을 정리하는 함수
- directory: 체크포인트 파일들이 있는 디렉토리
- keep_last_n: 유지할 최근 체크포인트 개수
"""
function cleanup_old_checkpoints(directory::String, keep_last_n::Int)
    try
        # 체크포인트 파일들 찾기
        checkpoint_files = filter(x -> endswith(x, ".jld2"), readdir(directory, join=true))
        
        if length(checkpoint_files) <= keep_last_n
            return
        end
        
        # 파일 수정 시간 기준으로 정렬
        sort!(checkpoint_files, by=mtime)
        
        # 오래된 파일들 삭제
        for file in checkpoint_files[1:end-keep_last_n]
            rm(file)
            println("오래된 체크포인트 삭제됨: $file")
        end
    catch e
        println("체크포인트 정리 중 오류 발생: $e")
    end
end

"""
사용 예시:

# 체크포인트 저장
save_checkpoint(model, opt, 10, 0.5, "checkpoint_epoch_10.jld2")

# 체크포인트 로드
model, opt, epoch, loss = load_checkpoint("checkpoint_epoch_10.jld2")

# 오래된 체크포인트 정리 (최근 3개만 유지)
cleanup_old_checkpoints("checkpoints", 3)
"""

end # module
```

이 코드는 머신러닝 모델 학습 중 체크포인트를 관리하기 
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 54: Write a Julia function to implement context window management for long documents. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function for context window management with Korean comments:

```julia
"""
긴 문서를 처리하기 위한 컨텍스트 윈도우 관리 시스템
"""
struct ContextWindow
    # 전체 텍스트 내용
    text::String
    # 윈도우 크기 (토큰 또는 문자 수)
    window_size::Int
    # 윈도우 간 중첩되는 부분의 크기
    overlap::Int
end

"""
텍스트를 토큰으로 분할하는 함수
"""
function tokenize(text::String)
    # 간단한 공백 기반 토큰화
    return split(text)
end

"""
컨텍스트 윈도우를 생성하고 관리하는 주요 함수
"""
function create_context_windows(text::String, window_size::Int, overlap::Int)
    # 입력값 유효성 검사
    if window_size <= 0 || overlap < 0 || overlap >= window_size
        throw(ArgumentError("윈도우 크기와 중첩 크기가 유효하지 않습니다."))
    end

    # 텍스트를 토큰으로 분할
    tokens = tokenize(text)
    windows = []
    
    # 토큰의 총 개수가 윈도우 크기보다 작으면 전체를 하나의 윈도우로 반환
    if length(tokens) <= window_size
        return [tokens]
    end

    # 윈도우 생성
    start_idx = 1
    while start_idx <= length(tokens)
        # 현재 윈도우의 끝 인덱스 계산
        end_idx = min(start_idx + window_size - 1, length(tokens))
        
        # 현재 윈도우의 토큰들을 추출
        current_window = tokens[start_idx:end_idx]
        push!(windows, current_window)

        # 다음 윈도우의 시작점 계산
        start_idx += (window_size - overlap)

        # 마지막 토큰에 도달하면 종료
        if end_idx >= length(tokens)
            break
        end
    end

    return windows
end

"""
윈도우 내용을 문자열로 변환하는 함수
"""
function window_to_string(window::Vector{String})
    # 토큰들을 다시 문자열로 결합
    return join(window, " ")
end

"""
컨텍스트 윈도우 사용 예시
"""
function example_usage()
    # 예시 텍스트
    sample_text = "이것은 긴 문서를 처리하기 위한 예시 텍스트입니다. 컨텍스트 윈도우를 사용하여 문서를 관리합니다."
    
    # 컨텍스트 윈도우 생성
    windows = create_context_windows(sample_text, 5, 2)
    
    # 각 윈도우 출력
    for (i, window) in enumerate(windows)
        println("윈도우 $i: ", window_to_string(window))
    end
end
```

이 코드에 대한 설명:

### 주요 구성 요소:

1. `ContextWindow` 구조체:
   - 전체 텍스트 저장
   - 윈도우 크기 설정
   - 중첩 크기 설정

2. `tokenize` 함수:
   - 텍스트를 개별 토큰으로 분할
   - 현재는 간단
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 55: Write a Julia function to create hybrid search combining vector and keyword search. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
"""
하이브리드 검색 함수를 구현합니다. 벡터 검색과 키워드 검색을 결합하여 더 정확한 검색 결과를 제공합니다.

매개변수:
- query: 검색할 쿼리 문자열
- documents: 검색 대상 문서 배열
- vectors: 각 문서의 벡터 표현 (임베딩)
- weights: 벡터 검색과 키워드 검색의 가중치 (기본값: 0.7, 0.3)
- top_k: 반환할 상위 결과 개수 (기본값: 5)

반환값:
- 점수순으로 정렬된 상위 k개의 검색 결과 (인덱스와 점수)
"""
function hybrid_search(query::String, 
                      documents::Vector{String},
                      vectors::Matrix{Float64},
                      weights::Tuple{Float64,Float64}=(0.7, 0.3),
                      top_k::Int=5)
    
    # 입력값 유효성 검사
    @assert length(documents) == size(vectors,2) "문서 수와 벡터 수가 일치해야 합니다"
    @assert weights[1] + weights[2] ≈ 1.0 "가중치의 합은 1이어야 합니다"
    
    # 벡터 검색 점수 계산
    function vector_similarity(query_vec::Vector{Float64}, doc_vecs::Matrix{Float64})
        # 코사인 유사도 계산
        similarities = vec(query_vec' * doc_vecs)
        similarities ./ (norm(query_vec) * vec(sqrt.(sum(doc_vecs.^2, dims=1))))
    end
    
    # 키워드 검색 점수 계산 
    function keyword_similarity(query::String, documents::Vector{String})
        # 단어 빈도수 기반 유사도 계산
        query_words = lowercase.(split(query))
        scores = Float64[]
        for doc in documents
            doc_words = lowercase.(split(doc))
            matches = sum(w -> in(w, doc_words), query_words)
            push!(scores, matches / sqrt(length(query_words) * length(doc_words)))
        end
        scores
    end
    
    # 임시 쿼리 벡터 생성 (실제 구현시 임베딩 모델 사용 필요)
    query_vec = rand(size(vectors,1))
    
    # 벡터 검색과 키워드 검색 점수 계산
    vec_scores = vector_similarity(query_vec, vectors)
    key_scores = keyword_similarity(query, documents)
    
    # 최종 점수 계산 (가중치 적용)
    final_scores = weights[1] .* vec_scores .+ weights[2] .* key_scores
    
    # 상위 k개 결과 반환
    top_indices = partialsortperm(final_scores, 1:min(top_k,length(documents)), rev=true)
    
    # 결과를 튜플 배열로 반환 [(인덱스, 점수), ...]
    [(i, final_scores[i]) for i in top_indices]
end

# 사용 예시
"""
테스트를 위한 샘플 데이터를 생성하고 하이브리드 검색을 실행하는 예시입니다.
"""
function example_usage()
    # 샘플 문서
    documents = [
        "인공지능과 머신러닝 기술",
        "데이터 분석과
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 56: Write a Julia function to implement re-ranking algorithms for RAG results. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 RAG(Retrieval-Augmented Generation) 결과를 재순위화하는 Julia 함수들입니다:

```julia
# RAG 결과 재순위화를 위한 타입 정의
struct RAGResult
    content::String           # 검색된 문서 내용
    initial_score::Float64    # 초기 유사도 점수
    metadata::Dict           # 메타데이터
end

"""
상호 정보량(Cross-Entropy)을 기반으로 문서 재순위화
query: 사용자 쿼리
results: RAG 검색 결과 배열
"""
function reciprocal_rank_fusion(results::Vector{RAGResult}, k::Int=60)
    # RRF 점수 계산
    scores = Float64[]
    for (rank, _) in enumerate(results)
        rrf_score = 1.0 / (k + rank)
        push!(scores, rrf_score)
    end
    
    # 점수에 따라 결과 재정렬
    sorted_indices = sortperm(scores, rev=true)
    return results[sorted_indices]
end

"""
다양성을 고려한 재순위화
results: RAG 검색 결과 배열
λ: 다양성 가중치 (0~1)
"""
function diversity_reranking(results::Vector{RAGResult}, λ::Float64=0.5)
    n = length(results)
    final_scores = copy([r.initial_score for r in results])
    
    # 다양성 점수 계산
    for i in 1:n
        for j in 1:i-1
            # 문서 간 유사도 계산
            similarity = compute_similarity(results[i].content, results[j].content)
            penalty = λ * similarity
            final_scores[i] -= penalty
        end
    end
    
    # 최종 점수로 재정렬
    sorted_indices = sortperm(final_scores, rev=true)
    return results[sorted_indices]
end

"""
문서 간 유사도 계산 (코사인 유사도 사용)
"""
function compute_similarity(doc1::String, doc2::String)
    # 간단한 단어 빈도 벡터 생성
    words1 = split(lowercase(doc1))
    words2 = split(lowercase(doc2))
    
    # 공통 어휘 생성
    vocab = unique(vcat(words1, words2))
    
    # 단어 빈도 벡터 생성
    vec1 = [count(==(word), words1) for word in vocab]
    vec2 = [count(==(word), words2) for word in vocab]
    
    # 코사인 유사도 계산
    dot_product = sum(vec1 .* vec2)
    norm1 = sqrt(sum(vec1.^2))
    norm2 = sqrt(sum(vec2.^2))
    
    return dot_product / (norm1 * norm2)
end

"""
최종 재순위화 파이프라인
query: 사용자 쿼리
results: 초기 검색 결과
"""
function rerank_pipeline(query::String, results::Vector{RAGResult})
    # 1단계: RRF 적용
    rrf_results = reciprocal_rank_fusion(results)
    
    # 2단계: 다양성 재순위화 적용
    final_results = diversity_reranking(rrf_results)
    
    return final_results
end
```

위 코드에 대한 설명:

1. `RAGResult` 구조체:
   - 검색된 문서의 내용, 초기 점수, 메타데이터를 저장하는 
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 57: Write a Julia function to extract and index metadata from documents. Provide all comments and explanations in Korean (한국어).
Answer: # 문서 메타데이터 추출 및 인덱싱을 위한 Julia 함수를 작성하겠습니다.

```julia
using Dates

"""
메타데이터를 저장하기 위한 구조체
- title: 문서 제목
- author: 작성자
- date: 작성일
- keywords: 키워드 배열
- file_path: 파일 경로
"""
struct DocumentMetadata
    title::String
    author::String
    date::Date
    keywords::Vector{String}
    file_path::String
end

"""
문서에서 메타데이터를 추출하는 함수
text: 문서 전체 텍스트
file_path: 문서 파일 경로
"""
function extract_metadata(text::String, file_path::String)
    # 기본값 설정
    title = ""
    author = ""
    date = today()
    keywords = String[]
    
    # 텍스트를 줄 단위로 분할
    lines = split(text, "\n")
    
    # 각 줄을 순회하면서 메타데이터 추출
    for line in lines
        # 제목 추출 (예: "Title: 문서 제목")
        if startswith(lowercase(line), "title:")
            title = strip(split(line, ":")[2])
        
        # 작성자 추출 (예: "Author: 홍길동")
        elseif startswith(lowercase(line), "author:")
            author = strip(split(line, ":")[2])
            
        # 날짜 추출 (예: "Date: 2023-01-01")
        elseif startswith(lowercase(line), "date:")
            try
                date_str = strip(split(line, ":")[2])
                date = Date(date_str)
            catch
                # 날짜 형식이 잘못된 경우 현재 날짜 사용
                date = today()
            end
            
        # 키워드 추출 (예: "Keywords: julia, 프로그래밍, 메타데이터")
        elseif startswith(lowercase(line), "keywords:")
            keywords_str = strip(split(line, ":")[2])
            keywords = [strip(k) for k in split(keywords_str, ",")]
        end
    end
    
    # DocumentMetadata 구조체 생성 및 반환
    return DocumentMetadata(title, author, date, keywords, file_path)
end

"""
메타데이터 인덱스를 생성하는 함수
metadata_list: DocumentMetadata 객체의 배열
"""
function create_metadata_index(metadata_list::Vector{DocumentMetadata})
    # 인덱스 딕셔너리 초기화
    keyword_index = Dict{String, Vector{String}}()
    author_index = Dict{String, Vector{String}}()
    date_index = Dict{Date, Vector{String}}()
    
    # 각 메타데이터 객체에 대해 인덱스 생성
    for metadata in metadata_list
        # 키워드 인덱싱
        for keyword in metadata.keywords
            if !haskey(keyword_index, keyword)
                keyword_index[keyword] = String[]
            end
            push!(keyword_index[keyword], metadata.file_path)
        end
        
        # 작성자 인덱싱
        if !haskey(author_index, metadata.author)
            author_index[metadata.author] = String[]
        end
        push!(author_index[metadata.author], metadata.file_path)
        
        # 날짜 인덱싱
        if !haskey(date_index, metadata.date)
            date_index[metadata.date] = String[]
        end
        push!(date_index[metadata.date], metadata.file
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 58: Write a Julia function to implement document deduplication for training data. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
"""
문서 중복 제거를 위한 함수입니다.
입력: 
- documents: 문서 텍스트 배열
- threshold: 유사도 임계값 (0~1 사이 값)
출력:
- 중복이 제거된 문서 배열
"""
function deduplicate_documents(documents::Vector{String}, threshold::Float64=0.8)
    # 결과를 저장할 배열 초기화
    unique_docs = String[]
    
    # 입력값 유효성 검사
    if threshold < 0 || threshold > 1
        throw(ArgumentError("임계값은 0과 1 사이여야 합니다"))
    end
    
    # 문서가 비어있으면 빈 배열 반환
    if isempty(documents)
        return unique_docs
    end
    
    # 첫 번째 문서는 항상 포함
    push!(unique_docs, documents[1])
    
    # 각 문서에 대해 중복 검사
    for doc in documents[2:end]
        is_duplicate = false
        
        # 이미 저장된 문서들과 유사도 비교
        for unique_doc in unique_docs
            similarity = calculate_similarity(doc, unique_doc)
            
            # 임계값보다 유사도가 높으면 중복으로 판단
            if similarity >= threshold
                is_duplicate = true
                break
            end
        end
        
        # 중복이 아니면 결과 배열에 추가
        if !is_duplicate
            push!(unique_docs, doc)
        end
    end
    
    return unique_docs
end

"""
두 문서 간의 유사도를 계산하는 함수입니다.
자카드 유사도를 사용합니다.
"""
function calculate_similarity(doc1::String, doc2::String)
    # 문서를 단어 집합으로 변환
    words1 = Set(split(lowercase(doc1)))
    words2 = Set(split(lowercase(doc2)))
    
    # 자카드 유사도 계산
    # 교집합 크기 / 합집합 크기
    intersection = length(intersect(words1, words2))
    union_size = length(union(words1, words2))
    
    return union_size == 0 ? 0.0 : intersection / union_size
end

# 사용 예시
function example_usage()
    # 테스트용 문서 데이터
    docs = [
        "이것은 첫 번째 문서입니다",
        "이것은 첫번째 문서예요", # 유사 문서
        "완전히 다른 내용의 문서",
        "이것은 첫 번째 문서입니다", # 동일 문서
    ]
    
    # 중복 제거 실행
    unique_docs = deduplicate_documents(docs, 0.7)
    
    println("원본 문서 수: ", length(docs))
    println("중복 제거 후 문서 수: ", length(unique_docs))
    println("\n중복 제거된 문서:")
    for (i, doc) in enumerate(unique_docs)
        println("$i: $doc")
    end
end
```

위 코드는 다음과 같은 기능을 제공합니다:

### 주요 함수 설명:

1. `deduplicate_documents`: 
- 메인 중복 제거 함수
- 입력된 문서 배열에서 유사한 문서를 제거
- threshold 매개변수로 유사도 기준 설정 가능

2. `calculate_
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 59: Write a Julia function to create synthetic training data for domain adaptation. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
"""
도메인 적응을 위한 합성 훈련 데이터를 생성하는 함수입니다.

인수:
- n_samples: 생성할 샘플의 수
- source_domain: 원본 도메인의 특성 (평균과 표준편차)
- target_domain: 대상 도메인의 특성 (평균과 표준편차) 
- noise_level: 데이터에 추가할 노이즈의 크기

반환값:
- source_data: 원본 도메인 데이터
- target_data: 대상 도메인 데이터
- labels: 데이터 레이블
"""
function generate_domain_data(n_samples::Int, 
                            source_domain::Tuple{Float64, Float64},
                            target_domain::Tuple{Float64, Float64},
                            noise_level::Float64=0.1)
    
    # 난수 생성을 위한 시드 설정
    Random.seed!(42)
    
    # 원본과 대상 도메인의 평균과 표준편차 추출
    source_mean, source_std = source_domain
    target_mean, target_std = target_domain
    
    # 원본 도메인 데이터 생성
    source_data = source_mean .+ source_std * randn(n_samples, 2)
    
    # 대상 도메인 데이터 생성 
    target_data = target_mean .+ target_std * randn(n_samples, 2)
    
    # 노이즈 추가
    source_noise = noise_level * randn(n_samples, 2)
    target_noise = noise_level * randn(n_samples, 2)
    
    source_data += source_noise
    target_data += target_noise
    
    # 레이블 생성 (두 클래스)
    labels = zeros(Int, n_samples)
    for i in 1:n_samples
        # 단순한 결정 경계: x + y > 0 인 경우 클래스 1
        if source_data[i,1] + source_data[i,2] > 0
            labels[i] = 1
        end
    end
    
    return source_data, target_data, labels
end

"""
생성된 데이터를 시각화하는 함수입니다.

인수:
- source_data: 원본 도메인 데이터
- target_data: 대상 도메인 데이터 
- labels: 데이터 레이블
"""
function plot_domain_data(source_data, target_data, labels)
    # 산점도 생성
    scatter(source_data[:,1], source_data[:,2], 
           color=labels, label="원본 도메인", alpha=0.6)
    scatter!(target_data[:,1], target_data[:,2], 
            color=labels, label="대상 도메인", alpha=0.3)
    xlabel!("특성 1")
    ylabel!("특성 2")
    title!("도메인 적응 데이터")
end

# 사용 예시
using Random, Plots

# 데이터 생성
n_samples = 1000
source_domain = (0.0, 1.0)  # 원본 도메인 (평균=0, 표준편차=1)
target_domain = (2.0, 1.5)  # 대상 도메인 (평균=2, 표준편차=1.5)

source_data, target_data, labels = generate_domain_data(
    n_samples, source_domain, target_domain
)

# 데이터 시각화
plot_domain_data(source_data, target_data, labels)
```

위 코
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 60: Write a Julia function to implement data quality validation for LLM training. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# LLM 훈련 데이터의 품질을 검증하는 함수들을 구현합니다.

"""
데이터 품질 검증을 위한 주요 함수입니다.
입력 데이터셋에 대해 여러가지 품질 지표를 검사하고 결과를 반환합니다.
"""
function validate_llm_data(dataset::Vector{String}, 
                         min_length::Int=10, 
                         max_length::Int=1000)
    
    # 결과를 저장할 딕셔너리
    results = Dict{String, Any}()
    
    # 기본적인 데이터 통계
    results["총 샘플 수"] = length(dataset)
    
    # 텍스트 길이 검증
    lengths = length.(dataset)
    results["평균 길이"] = mean(lengths)
    results["최소 길이"] = minimum(lengths)
    results["최대 길이"] = maximum(lengths)
    
    # 길이 기준 검증
    short_samples = filter(x -> length(x) < min_length, dataset)
    long_samples = filter(x -> length(x) > max_length, dataset)
    results["짧은 샘플 수"] = length(short_samples)
    results["긴 샘플 수"] = length(long_samples)
    
    # 중복 검사
    unique_samples = unique(dataset)
    results["중복율"] = 1 - length(unique_samples)/length(dataset)
    
    return results
end

"""
텍스트의 품질을 점수화하는 함수입니다.
여러 기준에 따라 0-1 사이의 품질 점수를 반환합니다.
"""
function score_text_quality(text::String)
    score = 0.0
    
    # 길이 기반 점수 (10-1000자 사이가 적정)
    len = length(text)
    if 10 <= len <= 1000
        score += 0.3
    end
    
    # 문장 다양성 점수
    sentences = split(text, ".") 
    if length(unique(sentences))/length(sentences) > 0.8
        score += 0.2
    end
    
    # 특수문자 비율 점수 
    special_chars = count(ispunct, text)/len
    if special_chars < 0.1
        score += 0.2
    end
    
    # 대소문자 혼합 점수
    if count(isuppercase, text)/len > 0.1
        score += 0.3
    end
    
    return score
end

"""
데이터셋 전체의 품질을 분석하고 시각화하는 함수입니다.
주요 통계와 분포를 계산하고 결과를 출력합니다.
"""
function analyze_dataset_quality(dataset::Vector{String})
    # 품질 점수 계산
    scores = score_text_quality.(dataset)
    
    # 기본 통계량
    stats = Dict(
        "평균 품질 점수" => mean(scores),
        "중앙값" => median(scores),
        "표준편차" => std(scores)
    )
    
    # 품질 분포 계산
    poor = count(x -> x < 0.3, scores)
    fair = count(x -> 0.3 <= x < 0.7, scores)
    good = count(x -> x >= 0.7, scores)
    
    distribution = Dict(
        "낮은 품질(0.3 미만)" => poor/length(scores),
        "보통 품질(0.3-0.7)" => fair/length(scores),
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 61: Write a Julia function to handle multi-turn conversation context management. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 다중 대화 문맥을 관리하는 Julia 함수입니다:

```julia
# 대화 기록을 저장하기 위한 구조체 정의
mutable struct ConversationContext
    # 대화 기록을 저장하는 배열
    history::Vector{Dict{String, String}}
    # 최대 기록 유지 길이
    max_history::Int
    # 현재 대화 ID
    conversation_id::String
end

"""
    create_conversation()

    새로운 대화 컨텍스트를 생성하는 함수
"""
function create_conversation(max_history::Int=10)
    return ConversationContext(
        Vector{Dict{String, String}}(),
        max_history,
        string(uuid4())  # 고유한 대화 ID 생성
    )
end

"""
    add_message!(context, role, message)

    대화 컨텍스트에 새로운 메시지를 추가하는 함수
    - context: 대화 컨텍스트
    - role: 발화자 역할 ("user" 또는 "system")
    - message: 메시지 내용
"""
function add_message!(context::ConversationContext, role::String, message::String)
    # 새 메시지 생성
    new_message = Dict("role" => role, "content" => message, "timestamp" => now())
    
    # 메시지 추가
    push!(context.history, new_message)
    
    # 최대 기록 길이를 초과하면 가장 오래된 메시지 삭제
    if length(context.history) > context.max_history
        popfirst!(context.history)
    end
    
    return context
end

"""
    get_conversation_history(context)

    전체 대화 기록을 반환하는 함수
"""
function get_conversation_history(context::ConversationContext)
    return context.history
end

"""
    clear_conversation!(context)

    대화 기록을 초기화하는 함수
"""
function clear_conversation!(context::ConversationContext)
    empty!(context.history)
    context.conversation_id = string(uuid4())
    return context
end

"""
    get_last_n_messages(context, n)

    최근 n개의 메시지를 반환하는 함수
"""
function get_last_n_messages(context::ConversationContext, n::Int)
    start_idx = max(1, length(context.history) - n + 1)
    return context.history[start_idx:end]
end

# 사용 예시
function example_usage()
    # 새로운 대화 컨텍스트 생성
    context = create_conversation(5)  # 최대 5개 메시지 유지
    
    # 메시지 추가
    add_message!(context, "user", "안녕하세요!")
    add_message!(context, "system", "안녕하세요, 무엇을 도와드릴까요?")
    
    # 최근 메시지 확인
    recent_messages = get_last_n_messages(context, 2)
    
    return context, recent_messages
end
```

위 코드의 주요 기능 설명:

1. `ConversationContext` 구조체:
   - 대화 기록 저장
   - 최대 기록 유지 길이 설정
   - 대화 식별자 관리

2. 주요 함수들:
   - `create_conversation()`: 새 대화 시작
   - `add_message!()`: 메시지 추가
   - `get_conversation_history()`: 전체 기록 조회
   - `clear_conversation!()
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 62: Write a Julia function to implement token budget management for API costs. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
# 토큰 예산 관리를 위한 구조체와 함수들을 구현합니다.

"""
토큰 사용량을 추적하기 위한 구조체
- total_budget: 전체 사용 가능한 토큰 수
- remaining_budget: 남은 토큰 수 
- usage_history: 토큰 사용 이력을 저장하는 배열
"""
mutable struct TokenBudget
    total_budget::Int
    remaining_budget::Int
    usage_history::Vector{Tuple{DateTime,Int,String}}
end

"""
새로운 TokenBudget 객체를 생성합니다.
budget: 초기 총 토큰 수
"""
function create_token_budget(budget::Int)
    TokenBudget(budget, budget, [])
end

"""
토큰을 사용하고 사용량을 기록합니다.
budget: TokenBudget 객체
tokens: 사용할 토큰 수
description: 사용 용도 설명
"""
function use_tokens!(budget::TokenBudget, tokens::Int, description::String)
    # 충분한 토큰이 있는지 확인
    if tokens > budget.remaining_budget
        throw(ErrorException("토큰이 부족합니다: 필요한 토큰 $tokens, 남은 토큰 $(budget.remaining_budget)"))
    end
    
    # 토큰 사용 기록
    usage_time = Dates.now()
    push!(budget.usage_history, (usage_time, tokens, description))
    
    # 남은 토큰 수정
    budget.remaining_budget -= tokens
    
    return budget.remaining_budget
end

"""
특정 기간 동안의 토큰 사용량을 조회합니다.
budget: TokenBudget 객체
start_time: 조회 시작 시간
end_time: 조회 종료 시간
"""
function get_usage_in_period(budget::TokenBudget, start_time::DateTime, end_time::DateTime)
    # 주어진 기간 동안의 사용 기록 필터링
    period_usage = filter(x -> start_time <= x[1] <= end_time, budget.usage_history)
    
    # 총 사용량 계산
    total_tokens = sum(x -> x[2], period_usage)
    
    return period_usage, total_tokens
end

"""
현재 토큰 상태를 출력합니다.
budget: TokenBudget 객체
"""
function print_budget_status(budget::TokenBudget)
    println("===== 토큰 예산 상태 =====")
    println("총 예산: $(budget.total_budget)")
    println("남은 예산: $(budget.remaining_budget)")
    println("사용률: $(round((budget.total_budget - budget.remaining_budget) / budget.total_budget * 100, digits=2))%")
    println("========================")
end

# 사용 예시:
"""
# 예산 생성
budget = create_token_budget(1000)

# 토큰 사용
try
    use_tokens!(budget, 100, "텍스트 생성")
    use_tokens!(budget, 50, "이미지 생성")
    
    # 상태 출력
    print_budget_status(budget)
    
    # 특정 기간 사용량 조회
    start_time = DateTime(2023, 1, 1)
    end_time = Dates.now()
    usage, total = get_usage_in_period(budget, start_time, end_time)
    
catch e
    println("에러 발생: ", e)
end
"""
```

위 코드는 API 토큰 예산
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 63: Write a Julia function to create custom tokenizers for domain-specific vocabulary. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 도메인별 특화된 어휘를 위한 커스텀 토크나이저를 만드는 Julia 함수입니다:

```julia
module CustomTokenizer

# 토크나이저의 기본 구조체 정의
struct Tokenizer
    # 특수 토큰 사전
    special_tokens::Dict{String, String}
    # 정규식 패턴
    patterns::Vector{Tuple{Regex, Symbol}}
    # 단어 구분자
    delimiters::String
end

"""
사용자 정의 토크나이저를 생성하는 함수
params:
    - special_tokens: 특수 토큰 사전
    - patterns: 정규식 패턴 목록
    - delimiters: 구분자 문자열
"""
function create_tokenizer(;
    special_tokens::Dict{String, String} = Dict{String, String}(),
    patterns::Vector{Tuple{Regex, Symbol}} = Vector{Tuple{Regex, Symbol}}(),
    delimiters::String = " \n\t"
)
    return Tokenizer(special_tokens, patterns, delimiters)
end

"""
텍스트를 토큰으로 분리하는 함수
params:
    - tokenizer: 토크나이저 인스턴스
    - text: 입력 텍스트
returns:
    - 토큰 배열
"""
function tokenize(tokenizer::Tokenizer, text::String)
    tokens = String[]
    
    # 특수 토큰 처리
    current_text = text
    for (token, replacement) in tokenizer.special_tokens
        current_text = replace(current_text, token => " $replacement ")
    end
    
    # 텍스트를 단어로 분리
    words = split(current_text, Regex("[$(tokenizer.delimiters)]"), keepempty=false)
    
    for word in words
        # 정규식 패턴 매칭
        matched = false
        for (pattern, token_type) in tokenizer.patterns
            if occursin(pattern, word)
                push!(tokens, string(token_type, ":", word))
                matched = true
                break
            end
        end
        
        # 매칭되지 않은 경우 일반 토큰으로 처리
        if !matched
            push!(tokens, word)
        end
    end
    
    return tokens
end

# 예시 사용법을 보여주는 함수
function example_usage()
    # 의료 도메인 토크나이저 생성
    medical_tokenizer = create_tokenizer(
        special_tokens = Dict(
            "mg" => "UNIT_MG",
            "kg" => "UNIT_KG"
        ),
        patterns = [
            (r"^\d+$", :NUMBER),
            (r"^[A-Z]\d{2,}$", :CODE),
            (r"^[A-Za-z]+\d*$", :TERM)
        ],
        delimiters = " \n\t,."
    )
    
    # 테스트 텍스트
    text = "환자는 50kg 체중에 100mg 투약 필요. 진단코드 A123"
    
    return tokenize(medical_tokenizer, text)
end

end # module

# 모듈 사용 예시
# using .CustomTokenizer
# result = CustomTokenizer.example_usage()
# println(result)
```

위 코드에 대한 설명:

### 주요 구성 요소:

1. **구조체(Tokenizer)**
   - 특수 토큰 사전 저장
   - 정규식 패턴 목록 저장
   - 구분자 문자열 저장

2. **create_tokenizer 함수
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 64: Write a Julia function to implement beam search decoding for text generation. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
"""
빔 서치 디코딩을 구현한 함수입니다.
입력:
- model: 텍스트 생성 모델
- start_token: 시작 토큰
- vocab_size: 어휘 크기
- max_length: 최대 생성 길이
- beam_width: 빔의 너비
- end_token: 종료 토큰 (선택사항)
출력:
- 생성된 시퀀스들과 각각의 확률값
"""
function beam_search_decode(model, start_token, vocab_size, max_length, beam_width; end_token=nothing)
    # 초기 시퀀스와 확률값 설정
    sequences = [[start_token]]
    sequence_scores = [0.0]
    
    # 최대 길이까지 반복
    for i in 1:max_length
        # 모든 현재 시퀀스에 대한 후보들을 저장할 배열
        all_candidates = []
        
        # 각 시퀀스에 대해서
        for j in 1:length(sequences)
            seq = sequences[j]
            score = sequence_scores[j]
            
            # 종료 토큰에 도달했다면 해당 시퀀스 유지
            if end_token !== nothing && seq[end] == end_token
                push!(all_candidates, (score, seq))
                continue
            end
            
            # 모델을 통해 다음 토큰의 확률 예측
            probs = model(seq)  # 여기서는 모델이 확률을 반환한다고 가정
            
            # 가장 높은 확률을 가진 beam_width개의 토큰 선택
            top_probs, top_indices = findmaxk(probs, beam_width)
            
            # 새로운 후보 시퀀스들 생성
            for (prob, idx) in zip(top_probs, top_indices)
                new_seq = copy(seq)
                push!(new_seq, idx)
                new_score = score + log(prob)
                push!(all_candidates, (new_score, new_seq))
            end
        end
        
        # 모든 후보들 중에서 상위 beam_width개 선택
        sort!(all_candidates, rev=true)  # 점수가 높은 순으로 정렬
        sequences = [x[2] for x in all_candidates[1:min(beam_width, length(all_candidates))]]
        sequence_scores = [x[1] for x in all_candidates[1:min(beam_width, length(all_candidates))]]
    end
    
    return sequences, sequence_scores
end

# 사용 예시를 위한 간단한 더미 모델
"""
테스트를 위한 간단한 더미 모델입니다.
실제 구현시에는 실제 언어 모델로 교체해야 합니다.
"""
function dummy_model(seq)
    return rand(Float64, vocab_size)  # 랜덤한 확률값 반환
end

# 사용 예시
"""
실행 예시입니다:
- vocab_size = 1000  # 어휘 크기
- start_token = 1    # 시작 토큰
- beam_width = 3     # 빔 너비
- max_length = 10    # 최대 생성 길이
"""
function example_usage()
    vocab_size = 1000
    sequences, scores = beam_search_decode(dummy_model, 1, vocab_size, 10, 3)
    
    # 결과 출력
    for (seq, score) in zip(sequences, scores)
        println
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 65: Write a Julia function to apply temperature and top-k/top-p sampling strategies. Provide all comments and explanations in Korean (한국어).
Answer: ```julia
"""
텍스트 생성을 위한 sampling 전략들을 구현한 모듈입니다.
temperature와 top-k/top-p sampling을 지원합니다.
"""
module TextSampling

using StatsBase

"""
logits에 temperature를 적용합니다.
높은 temperature는 더 무작위한 sampling을, 낮은 temperature는 더 확실한 선택을 하도록 합니다.

Parameters:
- logits: 원본 logits 벡터
- temperature: sampling temperature (0보다 큰 실수)
"""
function apply_temperature(logits::Vector{Float32}, temperature::Float32)
    # temperature가 0에 가까우면 오버플로우 방지
    if temperature < 1e-8
        return logits
    end
    return logits ./ temperature
end

"""
top-k sampling을 수행합니다.
가장 확률이 높은 k개의 토큰만 남기고 나머지는 제거합니다.

Parameters:
- logits: 원본 logits 벡터
- k: 선택할 상위 토큰 개수
"""
function top_k_sampling(logits::Vector{Float32}, k::Int)
    if k >= length(logits)
        return logits
    end
    
    # k번째로 큰 값 찾기
    kth_value = partialsort(logits, k, rev=true)
    
    # k번째 값보다 작은 logits은 -Inf로 설정
    return map(x -> x >= kth_value ? x : -Inf32, logits)
end

"""
top-p (nucleus) sampling을 수행합니다.
누적 확률이 p가 될 때까지의 상위 토큰들만 남기고 나머지는 제거합니다.

Parameters:
- logits: 원본 logits 벡터  
- p: 누적 확률 임계값 (0과 1 사이)
"""
function top_p_sampling(logits::Vector{Float32}, p::Float32)
    # softmax 적용하여 확률 분포로 변환
    probs = softmax(logits)
    
    # 확률 내림차순 정렬
    sorted_indices = sortperm(probs, rev=true)
    cumsum_probs = cumsum(probs[sorted_indices])
    
    # 임계값 p를 넘는 지점까지의 인덱스만 유지
    cut_off_idx = findfirst(x -> x >= p, cumsum_probs)
    
    # 결과 logits 생성
    result = fill(-Inf32, length(logits))
    result[sorted_indices[1:cut_off_idx]] = logits[sorted_indices[1:cut_off_idx]]
    
    return result
end

"""
softmax 함수를 구현합니다.
수치 안정성을 위해 최댓값을 빼고 계산합니다.

Parameters:
- x: 입력 벡터
"""
function softmax(x::Vector{Float32})
    x_max = maximum(x)
    exp_x = exp.(x .- x_max)
    return exp_x ./ sum(exp_x)
end

"""
주어진 logits에서 다음 토큰을 sampling합니다.
temperature, top-k, top-p 전략을 모두 적용할 수 있습니다.

Parameters:
- logits: 원본 logits 벡터
- temperature: sampling temperature
- k: top-k sampling을 위한 k 값 (optional)
- p: top-p sampling을 위한 p 값 (optional)
"""
function sample_next_token
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 66: Write a Julia function to implement grammar-constrained generation. Provide all comments and explanations in Korean (한국어).
Answer: 다음은 문법 제약 기반 생성을 구현하는 Julia 함수입니다:

```julia
# 문법 규칙을 정의하는 타입
struct GrammarRule
    name::String
    expansions::Vector{Vector{String}}
end

"""
    generate_from_grammar(grammar::Dict{String, GrammarRule}, start_symbol::String, max_depth::Int=10)

문법 규칙에 따라 텍스트를 생성하는 함수
- grammar: 문법 규칙을 담고 있는 사전
- start_symbol: 시작 기호
- max_depth: 최대 재귀 깊이
"""
function generate_from_grammar(grammar::Dict{String, GrammarRule}, 
                             start_symbol::String, 
                             max_depth::Int=10)
    # 최대 깊이 도달 시 중단
    if max_depth <= 0
        return start_symbol
    end
    
    # 시작 기호가 문법에 없으면 그대로 반환
    if !haskey(grammar, start_symbol)
        return start_symbol
    end
    
    # 현재 규칙에서 무작위로 확장 규칙 선택
    rule = grammar[start_symbol]
    expansion = rand(rule.expansions)
    
    # 각 토큰에 대해 재귀적으로 확장
    result = String[]
    for token in expansion
        generated = generate_from_grammar(grammar, token, max_depth - 1)
        push!(result, generated)
    end
    
    # 결과를 공백으로 연결하여 반환
    return join(result, " ")
end

# 사용 예시를 위한 간단한 문법 규칙 정의
function create_sample_grammar()
    grammar = Dict{String, GrammarRule}()
    
    # 문장 구조
    grammar["S"] = GrammarRule("S", [["NP", "VP"]])
    
    # 명사구
    grammar["NP"] = GrammarRule("NP", [["DET", "N"], ["DET", "ADJ", "N"]])
    
    # 동사구
    grammar["VP"] = GrammarRule("VP", [["V"], ["V", "NP"]])
    
    # 터미널 심볼
    grammar["DET"] = GrammarRule("DET", [["the"], ["a"]])
    grammar["N"] = GrammarRule("N", [["cat"], ["dog"], ["bird"]])
    grammar["ADJ"] = GrammarRule("ADJ", [["big"], ["small"], ["happy"]])
    grammar["V"] = GrammarRule("V", [["sleeps"], ["runs"], ["jumps"]])
    
    return grammar
end

# 테스트 코드
function test_grammar_generation()
    grammar = create_sample_grammar()
    println("생성된 문장:")
    for i in 1:5
        sentence = generate_from_grammar(grammar, "S")
        println("$i. $sentence")
    end
end
```

# 주요 설명:

### 구조 설명
- `GrammarRule`: 문법 규칙을 나타내는 구조체
  - `name`: 규칙의 이름
  - `expansions`: 가능한 확장 규칙들의 배열

### 주요 함수 설명
- `generate_from_grammar`: 문법에 따라 텍스트를 생성하는 메인 함수
  - 재귀적으로 각 규칙을 확장하며 문장을 생성
  - 최대 깊이 제한으로 무한 재귀 방지

### 사용법
```julia
# 테스트 
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 67: Write a Julia function to detect and prevent model hallucinations. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function to help detect and prevent model hallucinations:

```julia
"""
모델 환각 현상을 감지하고 방지하기 위한 함수들
"""
module HallucinationDetector

using Statistics

"""
입력 텍스트의 일관성을 검사하는 함수
- text: 검사할 텍스트
- reference_data: 참조 데이터 (신뢰할 수 있는 사실 데이터)
- threshold: 일관성 점수 임계값 (기본값: 0.7)
"""
function check_consistency(text::String, reference_data::Dict, threshold::Float64=0.7)
    # 텍스트를 단어 단위로 분리
    words = split(lowercase(text))
    
    # 참조 데이터와 일치하는 키워드 수 계산
    matches = 0
    for word in words
        if haskey(reference_data, word)
            matches += 1
        end
    end
    
    # 일관성 점수 계산
    consistency_score = matches / length(words)
    
    return consistency_score >= threshold
end

"""
텍스트의 불확실성을 측정하는 함수
- text: 분석할 텍스트
- uncertainty_markers: 불확실성을 나타내는 단어 목록
"""
function measure_uncertainty(text::String, uncertainty_markers::Vector{String})
    # 텍스트를 소문자로 변환하고 단어로 분리
    words = split(lowercase(text))
    
    # 불확실성 마커의 출현 횟수 계산
    uncertainty_count = sum(marker in words for marker in uncertainty_markers)
    
    # 불확실성 점수 계산 (0~1 사이)
    uncertainty_score = uncertainty_count / length(words)
    
    return uncertainty_score
end

"""
주어진 텍스트가 환각일 가능성을 평가하는 메인 함수
- text: 평가할 텍스트
- reference_data: 참조 데이터
- uncertainty_markers: 불확실성 마커
- consistency_threshold: 일관성 임계값
- uncertainty_threshold: 불확실성 임계값
"""
function detect_hallucination(
    text::String,
    reference_data::Dict,
    uncertainty_markers::Vector{String};
    consistency_threshold::Float64=0.7,
    uncertainty_threshold::Float64=0.1
)
    # 일관성 검사
    is_consistent = check_consistency(text, reference_data, consistency_threshold)
    
    # 불확실성 측정
    uncertainty_score = measure_uncertainty(text, uncertainty_markers)
    
    # 환각 가능성 평가
    is_hallucination = !is_consistent || uncertainty_score > uncertainty_threshold
    
    return Dict(
        "is_hallucination" => is_hallucination,
        "consistency_check" => is_consistent,
        "uncertainty_score" => uncertainty_score
    )
end

"""
사용 예시:
"""
function example_usage()
    # 참조 데이터 설정
    reference_data = Dict(
        "지구" => true,
        "태양" => true,
        "달" => true
    )
    
    # 불확실성 마커 설정
    uncertainty_markers = [
        "아마도",
        "일수도",
        "추측",
        "가능성"
    ]
    
    # 테스트 텍스트
    test_text = "지구는 아마도 태양계에서 세 번째 행성일 것입니다"
    
    # 환각 감지 실행
    result = detect_hallucination(
        test_text
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

Question 68: Write a Julia function to implement response quality scoring and filtering. Provide all comments and explanations in Korean (한국어).
Answer: Here's a Julia function for response quality scoring and filtering with Korean comments:

```julia
# 응답 품질 점수 및 필터링을 위한 모듈
module ResponseQualityScoring

# 필요한 패키지 가져오기
using Statistics
using DataFrames

"""
응답 품질 점수를 계산하고 필터링하는 주요 함수
parameters:
    - responses: 응답 데이터를 포함하는 DataFrame
    - min_score: 필터링을 위한 최소 품질 점수 (기본값: 0.7)
returns:
    - 필터링된 응답과 품질 점수를 포함하는 DataFrame
"""
function score_and_filter_responses(responses::DataFrame, min_score::Float64=0.7)
    # 결과를 저장할 새로운 DataFrame 생성
    scored_responses = copy(responses)
    scored_responses.quality_score = zeros(nrow(responses))

    # 각 응답에 대해 품질 점수 계산
    for i in 1:nrow(responses)
        # 개별 품질 지표 계산
        completion_score = calculate_completion_score(responses[i, :])
        consistency_score = check_response_consistency(responses[i, :])
        time_score = evaluate_response_time(responses[i, :])
        
        # 최종 품질 점수 계산 (가중 평균)
        final_score = (
            completion_score * 0.4 + 
            consistency_score * 0.4 + 
            time_score * 0.2
        )
        
        scored_responses[i, :quality_score] = final_score
    end

    # 최소 점수 기준으로 필터링
    filtered_responses = filter(
        row -> row.quality_score >= min_score, 
        scored_responses
    )

    return filtered_responses
end

"""
응답 완성도 점수 계산
필수 필드의 작성 여부와 응답 길이를 확인
"""
function calculate_completion_score(response::DataFrameRow)
    # 필수 필드 목록
    required_fields = [:question1, :question2, :question3]
    
    # 필수 필드 완성도 확인
    completed_fields = sum([!ismissing(response[field]) for field in required_fields])
    completion_ratio = completed_fields / length(required_fields)
    
    return completion_ratio
end

"""
응답 일관성 검사
응답 내용의 논리적 일관성을 확인
"""
function check_response_consistency(response::DataFrameRow)
    consistency_score = 1.0
    
    # 여기에 일관성 검사 로직 구현
    # 예: 상호 배타적인 응답 확인, 논리적 모순 검사 등
    
    return consistency_score
end

"""
응답 시간 평가
응답 시간의 적절성 검사
"""
function evaluate_response_time(response::DataFrameRow)
    # 최소 및 최대 적정 응답 시간 (초 단위)
    MIN_TIME = 30
    MAX_TIME = 600
    
    response_time = response.completion_time
    
    if response_time < MIN_TIME
        return 0.5  # 너무 빠른 응답
    elseif response_time > MAX_TIME
        return 0.7  # 너무 느린 응답
    else
        return 1.0  # 적정 시간 내 응답
    end
end

# 사용 예시를 위한 테스트 데이터 생성 함수
function create_test_data(n_responses::Int)
    #
Model: claude-3-5-sonnet-20241022
Tokens: 1024

============================================================

