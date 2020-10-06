#include <stdio.h>
#include <unistd.h>
#include <time.h>

#include "bdbmpcie.h"
#include "dmasplitter.h"

#define LOG_NUM 4
const char log_file_name[LOG_NUM][100] = { "/mnt/hdd0/data/hpc4/bgl2.log",
    "/mnt/hdd0/data/hpc4/liberty2.log",
    "/mnt/hdd0/data/hpc4/spirit2.log", 
    "/mnt/hdd0/data/hpc4/Thunderbird.log"};


int main(int argc, char** argv) {
    FILE *fin = fopen(log_file_name[0], "rb");
    uint32_t file_size = 0;
    uint32_t buff_size = 0;

    BdbmPcie* pcie = BdbmPcie::getInstance();

    /* Get file size */
    fseek(fin, 0, SEEK_END);
    file_size = ftell(fin);
    buff_size = file_size / 4;
    if (file_size % 4 != 0)
        buff_size++;
    rewind(fin);

    /* Read data from the file */
    uint32_t *log_data = (uint32_t *)malloc(buff_size * sizeof(uint32_t));
    fread(log_data, sizeof(char), file_size, fin);

    /* Put size */
    pcie->userWriteWord(0, file_size);

    /* Put data */
    /* for (int i = 0; i < buff_size; ++i)
     *     pcie->userWriteWord(4, log_data[i]); */

    /* test (You have to increase Tokenizers' output FIFO size)*/
    for (int i = 0; i < 5000; ++i)
        pcie->userWriteWord(4, log_data[i]);

    for (int i = 0; i < 5000; ++i) {
        uint32_t getd = pcie->userReadWord(0);
        log_data[i] = getd;
    }

    printf("Data sending is done \n");
    sleep(3);

    return 0;
}
