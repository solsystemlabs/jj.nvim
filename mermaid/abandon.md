# Abandon Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press x on commit| C[Single Commit Abandon]
    B -->|Select multiple + x| D[Multi-Commit Abandon]
    B -->|leader+a action menu| E[Action Menu]
    
    %% Single Commit Abandon Flow
    C --> F{Root Commit?}
    F -->|Yes| G[Show error - cannot abandon root]
    F -->|No| H[Show confirmation dialog]
    
    H --> I{User Confirms?}
    I -->|Yes| J[abandon_commit]
    I -->|No| K[Cancel operation]
    
    %% Multi-Commit Abandon Flow
    D --> L[Space-bar Multi-Select]
    L --> M[Validate selections]
    M --> N{Contains Root?}
    N -->|Yes| O[Show error - cannot abandon root]
    N -->|No| P[Show confirmation dialog]
    
    P --> Q{User Confirms?}
    Q -->|Yes| R[abandon_multiple_commits]
    Q -->|No| S[Cancel operation]
    
    %% Action Menu Flow
    E --> T{Menu Selection}
    T -->|Single Selection| U[Abandon commit x]
    T -->|Multi Selection| V[Abandon selected commits x]
    U --> F
    V --> L
    
    %% Single Abandon Execution
    J --> W[Extract change_id]
    W --> X[Build jj abandon command]
    X --> Y[commands.execute_with_immutable_prompt]
    Y --> Z[Execute jj abandon change_id]
    
    %% Multi Abandon Execution
    R --> AA{Async Mode?}
    AA -->|Yes| BB[abandon_multiple_commits_async]
    AA -->|No| CC[Sequential abandon]
    
    BB --> DD[Show progress indicator]
    DD --> EE[Process commits in parallel]
    EE --> FF[Update progress]
    FF --> GG[Complete with results]
    
    CC --> HH[Process commits sequentially]
    HH --> II[Execute each abandon]
    II --> JJ[Collect results]
    
    %% Common Completion
    Z --> KK{Success?}
    GG --> LL{All Success?}
    JJ --> MM{All Success?}
    
    KK -->|Yes| NN[Show success notification]
    KK -->|No| OO[Show error message]
    
    LL -->|Yes| PP[Show success notification]
    LL -->|No| QQ[Show partial success message]
    
    MM -->|Yes| RR[Show success notification]
    MM -->|No| SS[Show error summary]
    
    %% Final Steps
    NN --> TT[Refresh log display]
    PP --> TT
    RR --> TT
    OO --> UU[Return to previous state]
    QQ --> UU
    SS --> UU
    
    %% Error Handling
    G --> UU
    O --> UU
    K --> UU
    S --> UU
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef validation fill:#fff3e0
    classDef confirmation fill:#f3e5f5
    classDef execution fill:#e8f5e8
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    
    class A,B,C,D,E userAction
    class F,M,N,AA validation
    class H,I,P,Q,T,U,V confirmation
    class J,R,W,X,Y,Z,BB,CC,DD,EE,FF,GG,HH,II,JJ execution
    class NN,PP,RR,TT success
    class G,O,OO,QQ,SS,UU error
```

## Key Features

- **Root Commit Protection**: Cannot abandon the root commit
- **Confirmation Dialog**: User must confirm destructive operation
- **Multi-Select Support**: Space-bar selection for multiple commits
- **Async Support**: Progress indicators for multiple abandon operations
- **Error Handling**: Graceful failure with detailed error messages

## File Locations

- **Core**: `lua/jj-nvim/jj/abandon.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:502-506`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:119-123, 152-156`
- **Keybinding**: `x` key for abandon operation