# Create Elastic container  on  k3s

## k3s

k3s 是 kubernetes 輕量版，目的是用來做 container 管理和軟體load balence。  
我是用VMware開了 3 台虛擬機來做節點。

<table>
    <tr>
        <th>主機名</th>
        <th>IP</th>
    </tr>
    <tr>
        <td>k3s-master</td>
        <td>192.168.0.170</td>
    </tr>
    <tr>
        <td>k3s-node1</td>
        <td>192.168.0.171</td>
    </tr>
    <tr>
        <td>k3s-node2</td>
        <td>192.168.0.172</td>
    </tr>
</table>

### 快速安裝 k3s

1. 安裝 Master  

    ```bash
    # 安裝 k3s master 腳本
    curl -sfL https://get.k3s.io | sh -
    ```

    1. 取得 `K3S_TOKEN`  

        ```bash
        sudo cat /var/lib/rancher/k3s/server/node-token
        ```

    2. 查看目前節點

        ```bash
        sudo kubectl get nodes
        ```

2. 安裝 Node  
   需要先知道 Master 的 `IP` 和 `K3S_TOKEN`

    ```bash
    # 安裝 k3s node 腳本
    curl -sfL https://get.k3s.io | K3S_URL=https://{Master IP}:6443 K3S_TOKEN={K3S_TOKEN} sh -
    ```

### 安裝 Dashboard

1. 執行安命令

    ```bash
    # Dashboard 下載網址
    GITHUB_URL=https://github.com/kubernetes/dashboard/releases
    # 取得 Dashboard  最新版本號
    VERSION_KUBE_DASHBOARD=$(curl -w '%{url_effective}' -I -L -s -S ${GITHUB_URL}/latest -o /dev/null | sed -e 's|.*/||')
    # 透過 Dashboard 專案提供版來建立 k3s 物件 
    sudo k3s kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/${VERSION_KUBE_DASHBOARD}/aio/deploy/recommended.yaml
    ```

2. Dashboard 的 RBAC 設定

    1. 建立 [`dashboard.admin-user.yml`](./dashboard.admin-user.yml) 檔案

        ```yaml
        # 目的是為了建立一個 ServiceAccount 為 admin-user
        apiVersion: v1
        kind: ServiceAccount
        metadata:
            name: admin-user
            namespace: kubernetes-dashboard
        ```

    2. 建立 [`dashboard.admin-user-role.yml`](./dashboard.admin-user-role.yml) 檔案

        ```yaml
        # 目的是為了建立一個 ClusterRole 為 cluster-admin，並且包含 admin-user 這帳號
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRoleBinding
        metadata:
            name: admin-user
        roleRef:
            apiGroup: rbac.authorization.k8s.io
            kind: ClusterRole
            name: cluster-admin
        subjects:
           - kind: ServiceAccount
            name: admin-user
            namespace: kubernetes-dashboard
        ```

    3. 部屬 `admin-user` 設定

        ```bash
        sudo k3s kubectl create -f dashboard.admin-user.yml -f dashboard.admin-user-role.yml
        ```

    4. 取得 `Bearer Token`  
        要用這個 token 來登入 Dashboard

        ```bash
        sudo k3s kubectl -n kubernetes-dashboard describe secret admin-user-token | grep '^token'
        ```

    5. 存取 Dashboard  
        1. 使用 `proxy` 代理方式

            ```bash
            # 啟動 k3s API server 
            # 預設只會綁定本機 http://127.0.0.1:8001/
            kubectl proxy 

            # 讓API server可以接收所有主機網段來的 request
            kubectl proxy --address='0.0.0.0' --port=8002 --accept-hosts='^*$'
            ```

            使用 `proxy` 代理方式会使得 Dashboard 可以通过 http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/ 访问。

        2. 使用 `port-forward` 轉發port方式

            ```bash
            # 轉發本機 8080 port 到 service/kubernetes-dashboard 的 443 port
            # 綁定所有IP位址0.0.0.0            
            kubectl port-forward -n kubernetes-dashboard --address 0.0.0.0 service/kubernetes-dashboard 8080:443
            ```

            使用 `port-forward` 轉發方式会使得 Dashboard 可以通过 https://192.168.0.170:8080/

    6. 停止 proxy bind 的 port

        ```bash
        netstat -tulp | grep kubectl #列出 kubectl bind了那些port
        sudo kill -9 <pid> # kill process 就可以停止 listen port
        ```

### 啟用 nginx-Ingress 

1. 檢查驗證 Nginx Ingress POD是否運作正常:

    ```bash
    kubectl get pods -n ingress-nginx
    ```

    輸出如下:

    ```sh
    NAME                                        READY   STATUS      RESTARTS    AGE
    ingress-nginx-admission-create-g9g49        0/1     Completed   0          11m
    ingress-nginx-admission-patch-rqp78         0/1     Completed   1          11m
    ingress-nginx-controller-59b45fb494-26npt   1/1     Running     0          11m
    ```

2. 建立 [`dashboard-ingress.yaml`](elastic-yaml/dashboard-ingress.yaml) 檔案

    ```yaml
    # 目的是為了能透過使用網域 k3s.daesboard.info 的方式存取 Dashboard
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
        name: dashboard-ingress
        annotations:
            nginx.ingress.kubernetes.io/rewrite-target: /$1
    spec:
        rules:
            - host: k3s.daesboard.info
            http:
                paths:
                - path: /
                    pathType: Prefix
                    backend:
                    service:
                        name: kubernetes-dashboard
                        port:
                        number: 8080
    ```

3. 通过运行下面的命令创建 Ingress 对象：

    ```bash
    sudo kubectl apply -f dashboard-ingress.yaml
    ```

4. 修改hosts檔案  
    因為根本沒有`k3s.daesboard.info` 這個網域，要在hosts檔案裡面增加對應IP。
    就可以在瀏覽器輸入網址 `https://k3s.daesboard.info:8080` 打開 Dashboard。

    ```bash
    # hosts 所在路徑 
    # Linux: /etc/hosts
    # Mac OS X: /private/etc/hosts
    # Windows: C:\WINDOWS\system32\drivers\etc\hosts
    192.168.0.170 k3s.daesboard.info  # 加入對應IP
    ```

### Deploy elastic & Kiabna

1. 建立 Persistent Volume Claim

    ```bash
    sudo kubectl apply -f data01-persistentvolumeclaim.yaml,data02-persistentvolumeclaim.yaml,data03-persistentvol umeclaim.yaml,dbdata-persistentvolumeclaim.yaml
    ```

2. 建立 Network Policy

    ```bash
    sudo kubectl apply -f elastic-networkpolicy.yaml
    ```

3. 建立 Service

    ```bash
    sudo kubectl apply -f es001-service.yaml,es002-service.yaml,es003-service.yaml,kibana-service.yaml,mariadb-service.yaml
    ```

4. 建立 Deployment

    ```bash
    sudo kubectl apply -f es001-deployment.yaml,es002-deployment.yaml,es003-deployment.yaml,kibana-deploymen.yaml,mariadb-deployment.yaml
    ```

### 常用指令

```bash
# 查詢目前所有 namespace
kubectl get namespace 

# 查詢目前所有 pods
kubectl get pods
kubectl get pods --namespace=<insert-namespace-name-here>

# 查詢目前所有 Service
kubectl get service
kubectl get service --namespace=<insert-namespace-name-here>
```
