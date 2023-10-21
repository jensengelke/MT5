# Setup
1. Install [Git CLI](https://git-scm.com/download/win) (`64bit Git for Windows Setup`). Accept all default settings
1. Get the repository URL
    - Visit https://github.com/jensengelke/MT5
    - Click on "Code" 
    - Copy the URL ![copy url](docs/images/clone-repo-1.png)
1. With Git CLI installed, run
    ```bash
    git clone https://github.com/jensengelke/MT5.git
    cd MT5
    ```
1. Determine date folder path
    - In MT5, click `Open Data Folder` ![Data Folder](docs/images/open-data-folder.png)
    - Click the directory location and copy ![copy location](docs/images/copy-location.png)
1. Create directory links
    ```bash
    create-links.cmd <data folder path>
    ```
    ![create links](docs/images/clone-repo-2.png)


