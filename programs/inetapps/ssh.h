typedef enum {
    SSH_MSG_NONE, SSH_MSG_DISCONNECT, SSH_SMSG_PUBLIC_KEY,
    SSH_CMSG_SESSION_KEY, SSH_CMSG_USER, SSH_CMSG_AUTH_RHOSTS,
    SSH_CMSG_AUTH_RSA, SSH_SMSG_AUTH_RSA_CHALLENGE,
    SSH_CMSG_AUTH_RSA_RESPONSE, SSH_CMSG_AUTH_PASSWORD,
    SSH_CMSG_REQUEST_PTY, SSH_CMSG_WINDOW_SIZE, SSH_CMSG_EXEC_SHELL,
    SSH_CMSG_EXEC_CMD, SSH_SMSG_SUCCESS, SSH_SMSG_FAILURE,
    SSH_CMSG_STDIN_DATA, SSH_SMSG_STDOUT_DATA, SSH_SMSG_STDERR_DATA,
    SSH_CMSG_EOF, SSH_SMSG_EXITSTATUS,
    SSH_MSG_CHANNEL_OPEN_CONFIRMATION, SSH_MSG_CHANNEL_OPEN_FAILURE,
    SSH_MSG_CHANNEL_DATA, SSH_MSG_CHANNEL_CLOSE,
    SSH_MSG_CHANNEL_CLOSE_CONFIRMATION, SSH_MSG_OBSOLETED0,
    SSH_SMSG_X11_OPEN, SSH_CMSG_PORT_FORWARD_REQUEST, SSH_MSG_PORT_OPEN,
    SSH_CMSG_AGENT_REQUEST_FORWARDING, SSH_SMSG_AGENT_OPEN,
    SSH_MSG_IGNORE, SSH_CMSG_EXIT_CONFIRMATION,
    SSH_CMSG_X11_REQUEST_FORWARDING, SSH_CMSG_AUTH_RHOSTS_RSA,
    SSH_MSG_DEBUG, SSH_CMSG_REQUEST_COMPRESSION,
    SSH_CMSG_MAX_PACKET_SIZE, SSH_CMSG_AUTH_TIS,
    SSH_SMSG_AUTH_TIS_CHALLENGE, SSH_CMSG_AUTH_TIS_RESPONSE,
    SSH_CMSG_AUTH_KERBEROS, SSH_SMSG_AUTH_KERBEROS_RESPONSE,
} ssh_msg_type;

typedef enum {
    SSH_PHASE_NONE, SSH_PHASE_VERSION_WAIT, SSH_PHASE_GET_KEYS,
    SSH_PHASE_AUTH, SSH_PHASE_PREP, SSH_PHASE_PREP1, SSH_PHASE_INTERACTIVE
} ssh_phase;

typedef enum {
    SSH_CIPHER_NONE, SSH_CIPHER_IDEA, SSH_CIPHER_DES, SSH_CIPHER_3DES,
    SSH_CIPHER_TSS, SSH_CIPHER_RC4
} ssh_cipher_type;

typedef enum {
    SSH_AUTH_NONE, SSH_AUTH_RHOSTS, SSH_AUTH_RSA, SSH_AUTH_PASSWORD,
    SSH_AUTH_RHOSTS_RSA
} ssh_auth_type;