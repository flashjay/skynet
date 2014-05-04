#include <pthread.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>

#include "pbc.h"

struct args {
    int fd;
};

struct pbc_env * env;

static void
_readpbfile(const char *filename , struct pbc_slice *slice) {
    FILE *f = fopen(filename, "rb");
    if (f == NULL) {
        slice->buffer = NULL;
        slice->len = 0;
        return;
    }
    fseek(f,0,SEEK_END);
    slice->len = (int) ftell(f);
    fseek(f,0,SEEK_SET);
    slice->buffer = malloc(slice->len);
    fread(slice->buffer, 1 , slice->len , f);
    fclose(f);
}

static int
_recv(int fd, void * buffer, size_t sz) {
    for (;;) {
        int err = (int) recv(fd , buffer, sz, MSG_WAITALL);
        if (err < 0) {
            if (errno == EAGAIN || errno == EINTR) continue;
            break;
        }
        return err;
    }
    perror("Socket error");
    exit(1);
}

static void *
_read(void *ud) {
    struct args *p = ud;
    int fd = p->fd;
    fflush(stdout);
    for (;;) {
        uint8_t header[2];
        fflush(stdout);
        if (_recv(fd, header, 2) == 0)
            break;
        size_t len = header[0] << 8 | header[1];
        if (len>0) {
            char msg[len];
            _recv(fd, msg, len);
            struct pbc_slice slice;
            slice.len = (int)len;
            slice.buffer = msg;
            struct pbc_rmessage * r_msg = pbc_rmessage_new(env, "chat", &slice);
            printf("id = %d\n", pbc_rmessage_integer(r_msg , "id" , 0 , NULL));
            printf("name = %s\n", pbc_rmessage_string(r_msg , "name" , 0 , NULL));
            printf("text = %s\n", pbc_rmessage_string(r_msg , "text" , 0 , NULL));
        }
    }
    return NULL;
}

static void *
_send(void *ud) {
    struct args *p = ud;
    int fd = p->fd;

    char tmp[1024];
    int id = 0;
    while (!feof(stdin)) {
        memset(tmp, 0, sizeof(tmp));
        fgets(tmp, sizeof(tmp), stdin);
        size_t n = strlen(tmp)-1;
        tmp[n] = '\0';
        struct pbc_wmessage* w_msg = pbc_wmessage_new(env, "chat");
        struct pbc_slice sl;
        char buffer[1024];
        sl.buffer = buffer, sl.len = 1024;
        pbc_wmessage_integer(w_msg, "id",   ++id, 0);
        pbc_wmessage_string(w_msg, "name", "fy-c-client", -1);
        pbc_wmessage_string(w_msg, "text", tmp, -1);
        pbc_wmessage_buffer(w_msg, &sl);

        uint8_t head[2];
        head[0] = (sl.len >> 8) & 0xff;
        head[1] = sl.len & 0xff;
        ssize_t r;
        r = send(fd, head, 2, 0);
        if (r<0) {
            perror("send head");
        }
        r = send(fd, sl.buffer , sl.len, 0);
        if (r<0) {
            perror("send data");
        }
    }
    return NULL;
}

int 
main(int argc, char * argv[]) {
    if (argc < 3) {
        printf("connect address port\n");
        return 1;
    }

    env = pbc_new();
    struct pbc_slice slice;
    _readpbfile("./chat.pb", &slice);
    pbc_register(env, &slice);

    int fd = socket(AF_INET,SOCK_STREAM,0);
    struct sockaddr_in my_addr;

    my_addr.sin_addr.s_addr=inet_addr(argv[1]);
    my_addr.sin_family=AF_INET;
    my_addr.sin_port=htons(strtol(argv[2],NULL,10));

    int r = connect(fd,(struct sockaddr *)&my_addr,sizeof(struct sockaddr_in));

    if (r == -1) {
        perror("Connect failed:");
        return 1;
    }

    struct args arg = { fd };
    pthread_t pid ;
    pthread_create(&pid, NULL, _read, &arg);
    pthread_t pid_stdin;
    pthread_create(&pid_stdin, NULL, _send, &arg);

    pthread_join(pid, NULL); 

    close(fd);

    pbc_delete(env);
        
    return 0;
}
